import WakebarCore

struct UsageProviderPresentation: Equatable, Identifiable {
    let provider: ProviderID
    let bars: [UsageWindowBarModel]
    let issueMessage: String?

    var id: ProviderID { provider }
}
