package nl.aerius.jenkinslib.util

import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

def static calculateHmac256(String data, String secret) {
    String algorithm = 'HmacSHA256'
    SecretKeySpec signingKey = new SecretKeySpec(secret.getBytes('UTF-8'), algorithm)
    Mac mac = Mac.getInstance(algorithm)
    mac.init(signingKey)

    def hexString = mac.doFinal(data.getBytes('UTF-8')).encodeHex().toString()
    return "sha256=${hexString}"
}
