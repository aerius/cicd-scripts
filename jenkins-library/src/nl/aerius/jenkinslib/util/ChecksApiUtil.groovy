package nl.aerius.jenkinslib.util

def static stageStarted(def script, def title = 'The check has started...') {
  if (isPullRequestChecker(script)) {
    script.publishChecks(
      name    : script.env.STAGE_NAME,
      status  : 'IN_PROGRESS',
      title   : title
    )
  }
}

def static stageSkipped(def script, def title = 'Skipped') {
  if (isPullRequestChecker(script)) {
    script.publishChecks(
      name       : script.env.STAGE_NAME,
      title      : title,
      status     : 'COMPLETED',
      conclusion : 'SKIPPED'
    )
  }
}

def static stageCompletedWithSuccess(def script, def title = 'Success', def summary = '', def text = '') {
  if (isPullRequestChecker(script)) {
    script.publishChecks(
      name       : script.env.STAGE_NAME,
      title      : title,
      summary    : summary,
      text       : text,
      status     : 'COMPLETED',
      conclusion : 'SUCCESS'
    )
  }
}

def static stageCompletedWithFailure(def script, def title = 'Failure', def summary = '', def text = '') {
  if (isPullRequestChecker(script)) {
    script.publishChecks(
      name       : script.env.STAGE_NAME,
      title      : title,
      summary    : summary,
      text       : text,
      status     : 'COMPLETED',
      conclusion : 'FAILURE'
    )
  }
}

def static isPullRequestChecker(def script) {
  return script.env.JOB_NAME.toUpperCase().startsWith('PULLREQUESTCHECKER-')
}
