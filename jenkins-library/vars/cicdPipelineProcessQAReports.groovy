def call(Map config) {
  // jUnit
  // cucumber/k6 also write jUnit compatible files as well, so running that should also collect them
  if (config.qaJunitEnabled || config.qaCucumberEnabled || config.qaK6Enabled) {
    echo "### [cicdPipeline] - qaJunitEnabled / qaCucumberEnabled / qaK6Enabled.. Collecting junit test results"
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
