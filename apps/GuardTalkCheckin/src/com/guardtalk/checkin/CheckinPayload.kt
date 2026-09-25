package com.guardtalk.checkin

import org.json.JSONObject

/**
 * Builds the v1 JSON body. Port of checkin_contract.build_payload.
 * Never includes IMEI/serial/location/secrets.
 */
object CheckinPayload {

    private val DEVICE_ID = Regex("^[a-f0-9]{32,64}$")

    fun build(deviceId: String, sentAtUnix: Long, seq: Int, status: String): String {
        val did = deviceId.trim()
        if (!DEVICE_ID.matches(did)) {
            throw IllegalArgumentException("device_id must be 32-64 lowercase hex")
        }
        if (seq < 0 || sentAtUnix < 0L) {
            throw IllegalArgumentException("seq/sent_at_unix must be >= 0")
        }
        val body = JSONObject()
        body.put("schema", CheckinConstants.SCHEMA_ID)
        body.put("interval_s", CheckinConstants.INTERVAL_S)
        body.put("grace_s", CheckinConstants.GRACE_S)
        body.put("sent_at_unix", sentAtUnix)
        body.put("seq", seq)
        body.put("device_id", did)
        body.put("status", status)
        return body.toString()
    }
}
