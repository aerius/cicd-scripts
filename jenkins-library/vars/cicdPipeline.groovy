def call(Map config = [:], Closure body) {
  def agentLabel = config.agentLabel ?: 'any'

  def jobIsPrChecker = env.JOB_NAME.toUpperCase().startsWith('PULLREQUESTCHECKER-')
  def jobIsQA        = env.JOB_NAME.toUpperCase().startsWith('QA-')
  def jobIsDeploy    = env.JOB_NAME == 'DEPLOY-OTA-ENVIRONMENT'
  def jobIsBuild     = !jobIsQA && !jobIsPrChecker && !jobIsDeploy

  pipeline {
    // Use agent label from config if provided
    agent {
      label agentLabel == 'any' ? '' : agentLabel
    }

    stages {
      stage('PipelineWrapper') {
        steps {
          script {
            // Set build name
            buildName(sh(script: "${env.CICD_SCRIPTS_DIR}/job/get_build_name.sh", returnStdout: true))

            // Keep a list of ENVs we want to wrap the body with. Mostly for convenience and help clean up
            //  the Jenskinsfiles that make use of this pipeline.
            // What we wrap can be found below.
            def wrapperEnvs = []

            // Allow user to supply global environment configuration
            if (config.environment) {
              config.environment.each {
                key, value -> wrapperEnvs << "${key}=$value"
              }
            }
            // Also a script version, we do this so it runs in this context where a node is allocated
            // Without it will crash.. hard..
            if (config.environmentScripts) {
              config.environmentScripts.each {
                key, value -> wrapperEnvs << "${key}=" + sh(script: value, returnStdout: true)
              }
            }

            // Set Docker registry environment vars as last step if it's a build job.
            // Needed when the scripts in 'docker/images/' are used in the pipeline, which should always be the case for a build job.
            // Apart from convenience, this also makes sure that if these - for whatever arbitrary reason - get
            //  renamed or needs more vars, we can fix it for all pipelines by changing it here.
            if (jobIsBuild) {
              echo '### [cicdPipeline] - build job detected, setting Docker Registry vars'
              withCredentials([string(credentialsId: 'DOCKER_REGISTRY_HOSTNAME', variable: 'DOCKER_REGISTRY_HOSTNAME')]) {
                def AERIUS_REGISTRY_PATH = sh(script: "${env.CICD_SCRIPTS_DIR}/docker/get_registry_path.sh", returnStdout: true)
                wrapperEnvs << "AERIUS_REGISTRY_PATH=${AERIUS_REGISTRY_PATH}"
                wrapperEnvs << "AERIUS_REGISTRY_URL=${DOCKER_REGISTRY_HOSTNAME}/${AERIUS_REGISTRY_PATH}/"
                wrapperEnvs << "AERIUS_IMAGE_TAG=" + sh(script: "${env.CICD_SCRIPTS_DIR}/docker/get_image_tag.sh", returnStdout: true)
              }
            }

            // Run the actual body wrapped by the final global environment list we crafted
            withEnv(wrapperEnvs) {
              body()

              try {
                // Process any post jobs stuff
                if (jobIsBuild) {
                  cicdPipelineProcessPostJobBuild(config)
                }
              } catch (err) {
                echo "### [cicdPipeline] - Crashed in post-job actions"
                // First crash wins!
                if (!env.CICD_CRASHED_STAGE) {
                  env.CICD_CRASHED_STAGE = 'cicdPipeline: Post-Job actions'
                }
                throw err
              }
            }
          }
        }
      }
    }

    post {
      always {
        script {
          echo "### [cicdPipeline] - Finished. Current Status: ${currentBuild.currentResult}"

          // If QA job, we want to collect some reports based on what is requested by the pipeline
          if (jobIsQA) {
            cicdPipelineProcessQAReports(config)
          }

          // Always notify, except when the specific exclusions below apply.. this is rather extensive so I'll make it extra verbose
          def notify = true
          // Do not notify ...
          if (
            // for PR check jobs
            jobIsPrChecker
            // for build jobs
            || jobIsBuild
            // for deploy jobs if no one requested it specifically (nightlies for example - QA job will do the actual notifying)
            || (jobIsDeploy && !env.REQUESTED_BY_USER)
          ) {
            notify = false
          }

          // Force notify if a build didn't finish successfully, excluding PR check jobs
          if (!jobIsPrChecker && currentBuild.currentResult != 'SUCCESS') {
            notify = true
          }

          if (notify) {
            withBuildUser {
              // Append test status if it's a QA job
              def testStatusMessage = ''
              if (jobIsQA) {
                testStatusMessage = cicdGetTestStatusMessage()
                if (testStatusMessage != '') {
                  testStatusMessage = "\n\n```\n${testStatusMessage}\n```"
                }
              }

              def jobTypeString = ''
              jobTypeString = jobIsBuild  ? 'build' : jobTypeString
              jobTypeString = jobIsQA     ? 'QA'    : jobTypeString
              jobTypeString = jobIsDeploy ? (env.DEPLOY_TERRAFORM_ACTION == 'destroy' ? 'destroy' : 'deploy') : jobTypeString

              Map messageColors = [SUCCESS: 'good', FAILURE: 'danger']

              mattermostSend(
                channel: (env.MATTERMOST_CHANNEL ? "#${env.MATTERMOST_CHANNEL}" : null),
                color: messageColors.getOrDefault(currentBuild.result, 'warning'),
                message: sh(script: """${CICD_SCRIPTS_DIR}/job/notify_mattermost_message.sh "${currentBuild.result}" "${currentBuild.durationString}" "${jobTypeString}" """, returnStdout: true) + testStatusMessage
              )
            }
          }

          // Process post job webhooks and if web hooks are not working, mark job as unstable to signal this (not crashing on purpose).
          // At this time the webhooks used are just to help make stuff more user friendly, shouldn't be the end of the world if it crashes.
          catchError(buildResult: 'UNSTABLE', stageResult: 'UNSTABLE') {
            cicdPipelineProcessPostJobWebhooks(jobIsBuild, jobIsDeploy, jobIsPrChecker, jobIsQA)
          }
        }
      }
    }
  }
}
