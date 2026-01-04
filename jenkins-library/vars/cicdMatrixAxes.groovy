@NonCPS
def call(Map axes = [:]) {
  List result = []

  axes.each { axis, values ->
    List axisList = []
    values.each { value -> axisList << [(axis): value] }
    result << axisList
  }

  // calculate cartesian product
  result.combinations()*.sum()
}
