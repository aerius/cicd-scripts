package nl.aerius.jenkinslib.util

def static getEnvironment(def build) {
    // By default the job name is the environment
    def environment = build.projectName

    def parameters = build.rawBuild.getParameterValues()
    parameters.each { param ->
        if (param.name == 'SOURCE_JOB_NAME' || param.name == 'ENVIRONMENT_NAME') {
            environment = param.value
        }
    }

    return environment
}
