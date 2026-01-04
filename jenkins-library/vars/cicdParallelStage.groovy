import org.jenkinsci.plugins.pipeline.modeldefinition.Utils

def call(Map config = [:], String stageName, Closure body) {
  if (config.branches && !(config.branches instanceof List)) {
    // Hey, I wanted to let them know that I would be very disappointed if someone triggered this,
    //  but I think I kept the brunt of it out of the error message
    error("### [cicdParallelStage] - config.branches found with a non-List instance (${config.branches.class}) for stage: '${stageName}'.. Really? How did you figure that would work.. Crashing hard")
  }

  cicdStage(config, stageName) {
    Map tasks = [failFast: config.failFast ?: false] // do not fail fast by default, can be overriden

    // loop through all branches and create a task for it with the appropriate environment
    for (int i = 0; i < config.branches.size(); i++) {
      Map branch = config.branches[i]
      List branchEnv = branch.collect { k, v -> "${k}=${v}" }
      // always add an index to the Env, which can be used to make the stages unique
      branchEnv << "BRANCH_INDEX=${i}"

      tasks[branchEnv.join(', ')] = { ->
        withEnv(branchEnv) {
          body()
        }
      }
    }

    parallel tasks
  }
}
