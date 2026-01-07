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

              // Process any post jobs stuff
              if (jobIsBuild) {
                processBuildPostJob(config)
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
            processQAReports(config)
          }

          // Always notify, except when the specific exclusions below apply.. this is rather extensive so I'll make it extra verbose
          def notify = true
          // Do not notify ...
          if (
            // for PR check jobs
            jobIsPrChecker
            // for deploy jobs if no one requested it specifically (nightlies for example - QA job will do the actual notifying)
            || (jobIsDeploy && !env.REQUESTED_BY_USER)
            // for build jobs if it was a success (so do notify when it crashes or becomes unstable)
            || (jobIsBuild && currentBuild.currentResult == 'SUCCESS')
          ) {
            notify = false
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

              mattermostSend(
                channel: (env.MATTERMOST_CHANNEL ? "#${env.MATTERMOST_CHANNEL}" : null),
                color: sh(script: """${CICD_SCRIPTS_DIR}/job/notify_mattermost_color.sh "${currentBuild.result}" """, returnStdout: true),
                message: sh(script: """${CICD_SCRIPTS_DIR}/job/notify_mattermost_message.sh "${currentBuild.result}" "${currentBuild.durationString}" "${jobTypeString}" """, returnStdout: true) + testStatusMessage
              )
            }
          }
        }
      }
    }
  }
}

// this is the equivalent of the old job/postscript_*.sh script with some extra convenience wrappers
def processBuildPostJob(Map config) {
  // Get git URL from config, as this will contain the end result instead of posssibly variables that are replaced by Jenkins.
  // The PR builder for example uses dynamic git URLs.
  // trim() is needed as the output has a new line at the end causing havoc.
  def paramGitUrl = sh(script: "git config remote.origin.url", returnStdout: true).trim()  

  // For our custom temporary builds, use the proper environment name
  def paramJobName = env.JOB_NAME == 'STIKSTOFJE-DEPLOY-OTA-ENVIRONMENT' ? env.ENVIRONMENT_NAME : env.JOB_NAME

  // Jobs starting with UK-, should use the UK account by default, if account is already set, that has precedence
  def paramAwsAccountName = !env.AWS_ACCOUNT_NAME && paramJobName.toUpperCase().startsWith('UK-') ? 'UK-DEV' : (env.AWS_ACCOUNT_NAME ?: '')

  // If env.REQUESTED_BY_USER is not set and the job is triggered by a user, use this as the requester
  def paramRequestedByUser = !env.REQUESTED_BY_USER && env.BUILD_USER_ID && env.BUILD_USER_ID != 'ota-environment-deploy' ? env.BUILD_USER_ID : (env.REQUESTED_BY_USER ?: '')

  def jobParams = [
    string(name: 'SOURCE_JOB_NAME',          value: paramJobName),
    string(name: 'SOURCE_JOB_BUILD_NUMBER' , value: env.BUILD_NUMBER),
    string(name: 'DEPLOY_GIT_COMMIT',        value: env.GIT_COMMIT),
    string(name: 'DEPLOY_GIT_URL',           value: paramGitUrl),
    string(name: 'AERIUS_REGISTRY_URL',      value: env.AERIUS_REGISTRY_URL),
    string(name: 'DEPLOY_IMAGE_TAG',         value: env.AERIUS_IMAGE_TAG),
  ]
  // Add optional params, if not set they will fallback to default values set in the job itself
  [
    SERVICE_TYPE      : env.SERVICE_TYPE,
    SERVICE_THEME     : env.SERVICE_THEME,
    AWS_ACCOUNT_NAME  : paramAwsAccountName,
    FLAGS             : config.deployFlags,
    MATTERMOST_CHANNEL: env.MATTERMOST_CHANNEL,
    REQUESTED_BY_USER : paramRequestedByUser,
    CICD_JOB_MESSAGES : getJobMessagesAndAddCurrentJobDuration('build'),
  ].each {
    key, value -> if (value) { jobParams << string(name: key, value: value) }
  }
  if (env.DRY_RUN) { jobParams << string(name: 'DEPLOY_TERRAFORM_ACTION', value: 'dry-run') }

  // Trigger Terraform job that will do a deploy
  build(job: 'DEPLOY-OTA-ENVIRONMENT', parameters: jobParams, wait: false)
}

def processQAReports(Map config) {
  // jUnit
  if (config.qaJunitEnabled) {
    echo "### [cicdPipeline] - qaJunitEnabled.. Collecting junit test results"
    catchError(stageResult: 'FAILURE') {
      junit(testResults: config.qaJunitTestResults, allowEmptyResults: false)
    }
  }

  // Cucumber
  if (config.qaCucumberEnabled) {
    echo "### [cicdPipeline] - qaCucumberEnabled.. Collecting cucumber results"
    catchError(stageResult: 'FAILURE') {
      cucumber(jsonReportDirectory: config.qaCucumberJsonReportDirectory, fileIncludePattern: config.qaCucumberFileIncludePattern ?: '**/*.cucumber.json')
    }
  }

  // K6
  if (config.qaK6Enabled) {
    echo "### [cicdPipeline] - qaK6Enabled.. Collecting k6 test results"
    catchError(stageResult: 'FAILURE') {
      script {
        def dashboardFiles = findFiles(glob: "${config.qaK6ReportDir}/*.html")
        env.K6_DASHBOARD_FILES = []
        dashboardFiles.each() { dashboardFile ->
          echo "### [cicdPipeline] + Detected K6 dashboard file: ${dashboardFile.name}"
          env.K6_DASHBOARD_FILES << dashboardFile.name
        }
      }
      publishHTML([allowMissing: true,
        alwaysLinkToLastBuild: true,
        keepAll: true,
        includes: '*.html',
        icon: 'symbol-trigger',
        reportDir: config.qaK6ReportDir,
        reportFiles: env.K6_DASHBOARD_FILES.join(','),
        reportName: 'Performance tests'
      ])
    }
  }
}

def trimSuffix(String original, String suffix) {
  if (original.endsWith(suffix)) {
    return original.substring(0, original.length() - suffix.length())
  }

  return original
}

def getJobMessagesAndAddCurrentJobDuration(String durationType) {
  def result = env.CICD_JOB_MESSAGES ?: ''
  if (result) {
    result += ';'
  }

  result += "jobduration ${durationType} ${trimSuffix(currentBuild.durationString, 'and counting')}"

  return result
}
