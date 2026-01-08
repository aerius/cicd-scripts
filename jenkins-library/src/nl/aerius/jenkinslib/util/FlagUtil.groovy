package nl.aerius.jenkinslib.util

def static hasFlag(String allFlags, String flag) {
    return ",${allFlags},".contains(",${flag},")
}
