import org.jenkinsci.plugins.pipeline.modeldefinition.Utils

def call(Map config = [:], String stageName, Closure body) {
  if (config.when && !(config.when instanceof Boolean)) {
    // Hey, I wanted to let them know that I would be very disappointed if someone triggered this,
    //  but I think I kept the brunt of it out of the error message
    error("### [cicdStage] - config.when found with a non-boolean expression (${config.when.class}) for stage: '${stageName}'.. Really? How did you figure that would work.. Crashing hard")
  }

  // Only execute stage if when expression is not specified or when it evaluates to true
  //  (the above check makes sure it's a boolean so no need to do that here)
  if (config.when == null || config.when) {
    stage(stageName) {
      try {
        def wrapperEnvs = []

        // Allow user to supply environment configuration
        if (config.environment) {
          config.environment.each {
            key, value -> wrapperEnvs << "${key}=$value"
          }
        }

        // Run the actual body wrapped by the environment list we crafted
        withEnv(wrapperEnvs) {
          body()
        }
      } catch (err) {
        echo "### [cicdStage] - Crashed in stage: ${stageName}"
        // First crash wins!
        if (!env.CICD_CRASHED_STAGE) {
          env.CICD_CRASHED_STAGE = stageName
        }
        throw err
      }
    }
  } else {
    stage(stageName) {
      Utils.markStageSkippedForConditional(STAGE_NAME)
    }
  }
}
