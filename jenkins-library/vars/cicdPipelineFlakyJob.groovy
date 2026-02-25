def call(def build) {
  if (build.result == 'FAILURE') {
    def hiccups = [
      'Unable to locate credentials. You can configure credentials by running "aws configure"',
      'ERROR: mkdir /var/lib/docker/buildkit/',
    ]
    // Get last 150 log lines
    def logLines = build.rawBuild.getLog(150).join('\n')

    def foundHiccup = hiccups.find { hiccup ->
      logLines.contains(hiccup)
    }

    // This will return null if nothing is found as well, otherwise will return what matches
    return foundHiccup
  }

  return null
}
