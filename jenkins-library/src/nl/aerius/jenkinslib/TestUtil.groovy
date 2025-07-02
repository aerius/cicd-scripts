package nl.aerius.jenkinslib

import hudson.tasks.test.AbstractTestResultAction

def static getFailedCypressCount(AbstractTestResultAction testResultAction) {
    def failCypress = 0
    for (failedTest in testResultAction.getFailedTests()) {
        if (failedTest.getFullName().contains('.cypress.')) {
            failCypress++
        }
    }
    return failCypress
}

def static getPrettyDiff(def current, def previous) {
    if (previous == null) {
        return current
    } else {
        if (previous > current) {
            return "${current} (${current - previous})"
        } else {
            return "${current} (+${current - previous})"
        }
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
          testStatus = "Failed: ${getPrettyDiff(failed, failedPrevious)}\n  Cypress: ${getPrettyDiff(failedCypress, failedCypressPrevious)}\n  Unittests: ${getPrettyDiff(failedUnittests, failedUnittestsPrevious)}\nPassed: ${getPrettyDiff(passed, passedPrevious)}\nSkipped: ${getPrettyDiff(skipped, skippedPrevious)}"
        }
    }
    return testStatus
}
