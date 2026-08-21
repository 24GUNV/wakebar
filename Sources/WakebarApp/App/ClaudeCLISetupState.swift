enum ClaudeCLISetupState: Equatable {
    case checking
    case notFound
    case updateRequired(installed: String, required: String)
    case signInRequired(version: String)
    case unsupportedAuthentication(version: String, method: String)
    case ready(version: String)
    case launching
    case launched
    case failed(String)
}
