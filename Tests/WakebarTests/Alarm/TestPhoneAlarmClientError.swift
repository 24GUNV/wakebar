enum TestPhoneAlarmClientError: Error {
    case activeAlarmQueryFailed
    case cancelFailed
    case scheduleFailed
}
