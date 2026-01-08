import nl.aerius.jenkinslib.util.HashUtil

void call(def jobIsBuild, def jobIsDeploy, def jobIsPrChecker, def jobIsQA) {
  // Add information that we will always supply
  def payloadMap = [
    job : [
      name           : env.JOB_NAME,
      build_number   : env.BUILD_NUMBER,
      is_build       : jobIsBuild,
      is_deploy      : jobIsDeploy,
      is_prchecker   : jobIsPrChecker,
      is_qa          : jobIsQA,

      result         : currentBuild.result,
      crashed_stage  : env.CICD_CRASHED_STAGE
    ]
  ]

  // add a deploy block that's only available when it's a deploy job
  if (jobIsDeploy) {
    payloadMap << [
      deploy : [
        source_job_name          : env.SOURCE_JOB_NAME,
        source_job_build_number  : env.SOURCE_JOB_BUILD_NUMBER,
        git_url                  : env.DEPLOY_GIT_URL,
        git_commit               : env.DEPLOY_GIT_COMMIT,
        registry_url             : env.AERIUS_REGISTRY_URL,
        image_tag                : env.DEPLOY_IMAGE_TAG,
        service_theme            : env.SERVICE_THEME,
        flags                    : env.FLAGS,
        mattermost_channel       : env.MATTERMOST_CHANNEL,
        requested_by_user        : env.REQUESTED_BY_USER,
        terraform_action         : env.DEPLOY_TERRAFORM_ACTION
      ]
    ]
  }

  // add a QA block that's only available when it's a QA job
  if (jobIsQA) {
    payloadMap << [
      qa : [
        source_job_name          : env.SOURCE_JOB_NAME,
        source_job_build_number  : env.SOURCE_JOB_BUILD_NUMBER,
        git_url                  : env.DEPLOY_GIT_URL,
        git_commit               : env.DEPLOY_GIT_COMMIT,
        git_branch_specifier     : env.USE_GIT_BRANCH_SPECIFIER,
        registry_url             : env.AERIUS_REGISTRY_URL,
        image_tag                : env.DEPLOY_IMAGE_TAG,
        flags                    : env.FLAGS,
        service_theme            : env.SERVICE_THEME,
        mattermost_channel       : env.MATTERMOST_CHANNEL,
        requested_by_user        : env.REQUESTED_BY_USER
      ]
    ]
  }

  String payload = new groovy.json.JsonBuilder(payloadMap).toString()

  withCredentials([
    // Even though the name suggests it can contain multiple webhooks, for now it will only contain a single one.
    // I do not want to decide what the best separator might be going forward.. Future me's problem.. Life is extra good when ignoring such trivial stuff.
    string(credentialsId: 'CICD_SCRIPTS_PIPELINE_POST_WEBHOOKS',               variable: 'CICD_SCRIPTS_PIPELINE_POST_WEBHOOKS'),
    string(credentialsId: 'CICD_SCRIPTS_PIPELINE_POST_WEBHOOKS_CLIENT_SECRET', variable: 'CICD_SCRIPTS_PIPELINE_POST_WEBHOOKS_CLIENT_SECRET')
  ]) {
    // Create signature to send together with the request so the webhook can verify we are who we say we are (or someone who is very good at imitating us)
    String signature = HashUtil.calculateHmac256(payload, CICD_SCRIPTS_PIPELINE_POST_WEBHOOKS_CLIENT_SECRET)

    echo '### [cicdPipeline] - Calling post job webhook'
    // Call webhook
    def response = httpRequest(
      httpMode: 'POST',
      url: CICD_SCRIPTS_PIPELINE_POST_WEBHOOKS,
      quiet: true,
      contentType: 'APPLICATION_JSON',
      requestBody: payload,
      customHeaders: [
        [name: 'X-Hub-Signature-256', value: signature, maskValue: true]
      ]
    )
  }
}
