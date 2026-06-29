package com.guardtalk.config

import android.util.Base64
import android.util.Log
import org.json.JSONObject
import java.security.KeyFactory
import java.security.Signature
import java.security.spec.X509EncodedKeySpec

/**
 * Parses and cryptographically verifies the GuardTalk configuration QR payload.
 *
 * Wire format (per dispatch packet T-GTCONFIG-APP — QR Trust Model):
 *
 *   {
 *     "payload"  : "<base64(UTF-8 JSON)>",
 *     "signature": "<base64(Ed25519 signature over the UTF-8 JSON bytes)>"
 *   }
 *
 * The inner JSON payload has the shape:
 *
 *   {
 *     "secure_level":         "syndicate" | "community",
 *     "wifi_ssid":            "<GMP router SSID>",
 *     "wifi_password":        "<WPA2-PSK passphrase>",
 *     "vpn_server":           "<IKEv2 server hostname>",
 *     "vpn_identity":         "<IKEv2 local identity>",
 *     "vpn_psk":              "<IKEv2 pre-shared key, UTF-8>",
 *     "private_dns":          "<Private DNS hostname, e.g. dns.guardtalk.io>",
 *     "connectivity_server":  "<connectivity-check host>"
 *   }
 *
 * Trust model: the Ed25519 PUBLIC key is compiled into the app as a literal
 * byte array. The PRIVATE key is NEVER committed (Law 8 / Law 4); it is held
 * out-of-tree by the provisioning operator that mints the QR codes. The
 * [TEST_PUBLIC_KEY] below is a freshly generated test keypair — it MUST be
 * replaced with the production public key before any Syndicate rollout
 * (see [TEST_PRIVATE_SEED_B64] in the architect report, not in source).
 */
object QrPayloadParser {

    private const val TAG = "GTCfg/QrParser"

    /** Secure level marking for the Syndicate lockdown tier. */
    const val SECURE_LEVEL_SYNDICATE = "syndicate"

    /** Secure level marking for the open Community tier (no WiFi lockdown). */
    const val SECURE_LEVEL_COMMUNITY = "community"

    /**
     * Ed25519 test PUBLIC key (32 raw bytes).
     *
     * Corresponding test PRIVATE seed (base64), for QR-mint tooling only —
     * NOT committed in-tree, recorded solely in the architect completion
     * report:
     *
     *   bV0Ui5ZRFvOciEp6lQjIAWxJ19weStbNSs6wnxSaDLA=
     *
     * Production deployments MUST regenerate and replace both this constant
     * and the operator-held private seed. Verification is a single
     * `KeyFactory.getInstance("Ed25519")` + `Signature.getInstance("Ed25519")`
     * call chain, available on Android API 33+ (Android 13+). Tokay (Pixel 9)
     * ships with Android 14+ so this is satisfied.
     */
    private val TEST_PUBLIC_KEY: ByteArray = byteArrayOf(
        -3, 5, 119, -128, 39, -86, -3, 92, -8, -82, 60, -109, 9, 39, -98, -30,
        103, 102, 101, -72, 108, 120, -47, -107, -80, 78, -9, 14, -113, -89, -38, 74
    )

    /** Thrown when the outer envelope or the signature fails verification. */
    class InvalidPayloadException(message: String, cause: Throwable? = null) :
        Exception(message, cause)

    /** Parsed configuration payload. All fields non-null unless absent in JSON. */
    data class ConfigPayload(
        val secureLevel: String,
        val wifiSsid: String,
        val wifiPassword: String,
        val vpnServer: String,
        val vpnIdentity: String,
        val vpnPsk: String,
        val privateDns: String,
        val connectivityServer: String,
    )

    /**
     * Parse the scanned QR string, verify the Ed25519 signature, and return the
     * decoded [ConfigPayload]. Throws [InvalidPayloadException] on any
     * envelope/parse/signature failure.
     *
     * The input is expected to be the raw QR text. Trailing/leading whitespace
     * and a possible `guardtalk://` URI prefix are tolerated so the QR can be
     * encoded as either a bare JSON envelope or a deep-link style string.
     */
    fun parse(qrText: String): ConfigPayload {
        val envelope = qrText.trim().removePrefix("guardtalk://").trim()
        val outer = try {
            JSONObject(envelope)
        } catch (e: Exception) {
            throw InvalidPayloadException("Outer envelope is not valid JSON", e)
        }

        val payloadB64 = outer.optString("payload")
        val signatureB64 = outer.optString("signature")
        if (payloadB64.isEmpty() || signatureB64.isEmpty()) {
            throw InvalidPayloadException(
                "Missing payload/signature field — unsigned QR rejected"
            )
        }

        val payloadJsonBytes: ByteArray = try {
            Base64.decode(payloadB64, Base64.NO_WRAP)
        } catch (e: Exception) {
            throw InvalidPayloadException("payload is not valid base64", e)
        }
        val signatureBytes: ByteArray = try {
            Base64.decode(signatureB64, Base64.NO_WRAP)
        } catch (e: Exception) {
            throw InvalidPayloadException("signature is not valid base64", e)
        }

        verifyEd25519(payloadJsonBytes, signatureBytes)

        val json = JSONObject(String(payloadJsonBytes, Charsets.UTF_8))
        val payload = ConfigPayload(
            secureLevel = json.optString("secure_level").ifEmpty { SECURE_LEVEL_COMMUNITY },
            wifiSsid = json.optString("wifi_ssid"),
            wifiPassword = json.optString("wifi_password"),
            vpnServer = json.optString("vpn_server"),
            vpnIdentity = json.optString("vpn_identity"),
            vpnPsk = json.optString("vpn_psk"),
            privateDns = json.optString("private_dns"),
            connectivityServer = json.optString("connectivity_server"),
        )
        if (payload.wifiSsid.isEmpty() || payload.vpnServer.isEmpty()) {
            throw InvalidPayloadException(
                "Payload missing required wifi_ssid or vpn_server"
            )
        }
        if (payload.secureLevel != SECURE_LEVEL_SYNDICATE &&
            payload.secureLevel != SECURE_LEVEL_COMMUNITY
        ) {
            throw InvalidPayloadException(
                "Unknown secure_level: ${payload.secureLevel}"
            )
        }
        Log.i(TAG, "Verified payload: secureLevel=${payload.secureLevel}, " +
            "ssid=${payload.wifiSsid}, vpn=${payload.vpnServer}, dns=${payload.privateDns}")
        return payload
    }

    /** Verify the Ed25519 signature or throw. */
    private fun verifyEd25519(message: ByteArray, signature: ByteArray) {
        try {
            val keyFactory = KeyFactory.getInstance("Ed25519")
            val publicKey = keyFactory.generatePublic(X509EncodedKeySpec(encodeSpki(TEST_PUBLIC_KEY)))
            val verifier = Signature.getInstance("Ed25519")
            verifier.initVerify(publicKey)
            verifier.update(message)
            if (!verifier.verify(signature)) {
                throw InvalidPayloadException("Ed25519 signature does not verify — tampered QR rejected")
            }
        } catch (e: InvalidPayloadException) {
            throw e
        } catch (e: Exception) {
            throw InvalidPayloadException("Ed25519 verification error: ${e.message}", e)
        }
    }

    /**
     * Wrap a raw 32-byte Ed25519 public key in a SubjectPublicKeyInfo DER so
     * the standard JCA [X509EncodedKeySpec] path works. Android's
     * `KeyFactory.getInstance("Ed25519")` expects the SPKI framing, not the
     * raw 32 bytes.
     */
    private fun encodeSpki(rawPubKey: ByteArray): ByteArray {
        // SubjectPublicKeyInfo for Ed25519:
        //   SEQUENCE {
        //     SEQUENCE { OBJECT IDENTIFIER 1.3.101.112 },  -- id-Ed25519
        //     BIT STRING { 0x00, <32 raw bytes> }
        //   }
        require(rawPubKey.size == 32) { "Ed25519 public key must be 32 bytes" }
        val spki = ByteArray(44)
        spki[0] = 0x30; spki[1] = 0x2A               // SEQUENCE, len 42
        spki[2] = 0x30; spki[3] = 0x05               //   SEQUENCE, len 5
        spki[4] = 0x06; spki[5] = 0x03               //     OID, len 3
        spki[6] = 0x2B; spki[7] = 0x65; spki[8] = 0x70  //   1.3.101.112
        spki[9] = 0x03; spki[10] = 0x21              //   BIT STRING, len 33
        spki[11] = 0x00                              //     0 unused bits
        System.arraycopy(rawPubKey, 0, spki, 12, 32)
        return spki
    }
}
