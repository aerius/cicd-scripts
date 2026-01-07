package nl.aerius.jenkinslib.util

import hudson.tasks.test.AbstractTestResultAction

def static getFailedCypressCount(AbstractTestResultAction testResultAction) {
    def failCypress = 0
    for (failedTest in testResultAction.getFailedTests()) {
        // This matches both testcontainers and native Cypress tests at this time
        if (failedTest.getFullName().contains('.cypress.')) {
            failCypress++
        }
    }
    return failCypress
}

def static getFailedK6Count(AbstractTestResultAction testResultAction) {
    def failK6 = 0
    for (failedTest in testResultAction.getFailedTests()) {
        if (failedTest.getFullName().startsWith('k6.')) {
            failK6++
        }
    }
    return failK6
}

def static getPrettyDiff(def current, def previous) {
    if (previous == null || current == previous) {
        return sprintf('%6d', current)
    } else {
        def delta = previous > current ? "(${current - previous})" : "(+${current - previous})"
        return sprintf('%6d %6s', current, delta)
    }
}

def static getTestStatusMessage(def currentBuild) {
    def testStatus = ""
    AbstractTestResultAction testResultAction = currentBuild.rawBuild.getAction(AbstractTestResultAction.class)
    if (testResultAction != null) {
        def total           = testResultAction.totalCount
        def failed          = testResultAction.failCount
        def skipped         = testResultAction.skipCount
        def passed          = total - failed - skipped
        def failedCypress   = getFailedCypressCount(testResultAction)
        def failedK6        = getFailedK6Count(testResultAction)
        def failedUnittests = failed - failedCypress - failedK6

        def totalPrevious           = null
        def failedPrevious          = null
        def skippedPrevious         = null
        def passedPrevious          = null
        def failedCypressPrevious   = null
        def failedK6Previous        = null
        def failedUnittestsPrevious = null

        def previousResult = testResultAction.getPreviousResult()
        if (previousResult) {
            totalPrevious           = previousResult.totalCount
            failedPrevious          = previousResult.failCount
            skippedPrevious         = previousResult.skipCount
            passedPrevious          = totalPrevious - failedPrevious - skippedPrevious
            failedCypressPrevious   = getFailedCypressCount(previousResult)
            failedK6Previous        = getFailedK6Count(previousResult)
            failedUnittestsPrevious = failedPrevious - failedCypressPrevious
        }

        if (failed > 0 || (previousResult != null && failedPrevious > 0)) {
          def failedLines = ""
          if (failedCypress > 0 || (failedCypressPrevious != null && failedCypressPrevious > 0))
            failedLines += "\n            - Cypress   ${getPrettyDiff(failedCypress, failedCypressPrevious)}"
          if (failedK6 > 0 || (failedK6Previous != null && failedK6Previous > 0))
            failedLines += "\n            - K6        ${getPrettyDiff(failedK6, failedK6Previous)}"
          if (failedUnittests > 0 || (failedUnittestsPrevious != null && failedUnittestsPrevious > 0))
            failedLines += "\n            - Unittests ${getPrettyDiff(failedUnittests, failedUnittestsPrevious)}"

          testStatus = """\
            Failed      ${getPrettyDiff(failed, failedPrevious)}${failedLines}
            Passed      ${getPrettyDiff(passed, passedPrevious)}
            Skipped     ${getPrettyDiff(skipped, skippedPrevious)}
            """.stripIndent()
        }
    }
    return testStatus
}
