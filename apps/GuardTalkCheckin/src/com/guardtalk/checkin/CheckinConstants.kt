package com.guardtalk.checkin

/**
 * Constants for T-REMEDIATE-B4-CHECKIN. Must match
 * vendor/guardtalk/checkin/host/checkin_contract.py.
 */
object CheckinConstants {
    const val SCHEMA_ID = "guardtalk.checkin.v1"
    const val INTERVAL_S = 12 * 60 * 60
    const val INTERVAL_MS = INTERVAL_S * 1000L
    const val GRACE_S = 60 * 60
    const val ONESHOT_DEADLINE_MS = 15L * 60L * 1000L
    const val JOB_PERIODIC = 20
    const val JOB_ONESHOT = 21
    const val MAX_URL_LEN = 512
    const val DEFAULT_PATH = "/v1/checkin"

    const val GLOBAL_ENDPOINT = "guardtalk_checkin_endpoint"
    const val GLOBAL_SOCKS = "guardtalk_checkin_socks"
    const val GLOBAL_DEVICE_ID = "guardtalk_checkin_device_id"

    const val PREFS = "checkin"
    const val PREF_LAST_STATUS = "last_status"
    const val PREF_LAST_UNIX = "last_unix"
    const val PREF_SEQ = "seq"

    const val STATUS_OK = "ok"
    const val STATUS_SKIP_ENDPOINT = "skipped_no_endpoint"
    const val STATUS_SKIP_TOR = "skipped_no_tor"
    const val STATUS_REJECTED = "rejected_endpoint"
    const val STATUS_FAILED = "failed_transport"

    const val KIND_ONION = "onion"
    const val KIND_LAN = "gateway_lan"
}
