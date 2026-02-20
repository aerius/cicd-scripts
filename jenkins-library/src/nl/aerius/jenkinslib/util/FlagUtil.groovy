package nl.aerius.jenkinslib.util

def static hasFlag(String allFlags, String flag) {
    return ",${allFlags},".contains(",${flag},")
}

def static addFlag(String flags, String addFlag) {
    if (flags && addFlag) {
        return "${flags},${addFlag}"
    } else if (addFlag) {
        return addFlag
    }

    return flags
}
