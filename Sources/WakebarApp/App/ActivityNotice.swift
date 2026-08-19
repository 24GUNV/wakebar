struct ActivityNotice: Equatable {
    let message: String
    let kind: ActivityNoticeKind

    static func information(_ message: String) -> Self {
        Self(message: message, kind: .information)
    }

    static func success(_ message: String) -> Self {
        Self(message: message, kind: .success)
    }

    static func error(_ message: String) -> Self {
        Self(message: message, kind: .error)
    }
}
