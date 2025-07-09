package nl.aerius.jenkinslib

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
        def total = testResultAction.totalCount
        def failed = testResultAction.failCount
        def skipped = testResultAction.skipCount
        def passed = total - failed - skipped
        def failedCypress = getFailedCypressCount(testResultAction)
        def failedUnittests = failed - failedCypress
        def totalPrevious = null
        def failedPrevious = null
        def skippedPrevious = null
        def passedPrevious = null
        def failedCypressPrevious = null
        def failedUnittestsPrevious = null

        def previousResult = testResultAction.getPreviousResult()
        if (previousResult) {
            totalPrevious = previousResult.totalCount
            failedPrevious = previousResult.failCount
            skippedPrevious = previousResult.skipCount
            passedPrevious = totalPrevious - failedPrevious - skippedPrevious
            failedCypressPrevious = getFailedCypressCount(previousResult)
            failedUnittestsPrevious = failedPrevious - failedCypressPrevious
        }

        if (failed > 0 || (previousResult != null && failedPrevious > 0)) {
          testStatus = """\
            Failed      ${getPrettyDiff(failed, failedPrevious)}
            - Cypress   ${getPrettyDiff(failedCypress, failedCypressPrevious)}
            - Unittests ${getPrettyDiff(failedUnittests, failedUnittestsPrevious)}
            Passed      ${getPrettyDiff(passed, passedPrevious)}
            Skipped     ${getPrettyDiff(skipped, skippedPrevious)}
            """.stripIndent()
        }
    }
    return testStatus
}
