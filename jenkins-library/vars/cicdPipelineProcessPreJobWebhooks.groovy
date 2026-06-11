import nl.aerius.jenkinslib.WebhookType

void call(def jobIsBuild, def jobIsDeploy, def jobIsPrChecker, def jobIsQA) {
  cicdPipelineProcessJobWebhooks(WebhookType.PRE, jobIsBuild, jobIsDeploy, jobIsPrChecker, jobIsQA)
}
