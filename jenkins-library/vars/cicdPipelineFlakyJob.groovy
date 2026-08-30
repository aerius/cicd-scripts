def call(def build) {
  if (build.result == 'FAILURE') {
    def hiccups = [
      'Unable to locate credentials. You can configure credentials by running "aws configure"',
      'ERROR: mkdir /var/lib/docker/buildkit/',
      'ERROR: error during connect: Post "http://%2Fvar%2Frun%2Fdocker.sock',
      ': dial tcp ',
      'failed to register layer: symlink',
      'libnetwork.endpointCnt: Key not found in store.'
    ]
    // Get last 150 log lines
    def logLines = build.rawBuild.getLog(150).join('\n')

    def foundHiccup = hiccups.find { hiccup ->
      logLines.contains(hiccup)
    }

    // If a hiccup is found, add some debugging info that might help find some solutions for the flakiness.
    // These might fail if the disk is full, as Jenkins writes this to a temp file before executing.
    if (foundHiccup) {
      sh(script: '''#!/usr/bin/env sh
            set +e
            echo '### [cicdPipelineFlakyJob] - Hiccup detected, will print debugging information..'
            echo

            echo '### [cicdPipelineFlakyJob] - Disk usage'
            df -Th
            echo

            echo '### [cicdPipelineFlakyJob] - Inode usage'
            df -i
            echo

            echo '### [cicdPipelineFlakyJob] - Docker info'
            docker info
            echo

            echo '### [cicdPipelineFlakyJob] - Docker Disk usage'
            docker system df
            echo

            echo '### [cicdPipelineFlakyJob] - ECS Task Metadata'
            curl -s --max-time 3 "${ECS_CONTAINER_METADATA_URI_V4}/task"
            echo

            # Exit cleanly, ignoring any errors
            exit 0
        '''
      )
    }

    // This will return null if nothing is found as well, otherwise will return what matches
    return foundHiccup
  }

  return null
}
