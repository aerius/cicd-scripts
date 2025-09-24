package nl.aerius.jenkinslib

def static hasFlag(String allFlags, String flag) {
    return ",${allFlags},".contains(",${flag},")
}
