public actor ProviderExecutionCoordinator {
    private let ledger: ExecutionLedger

    public init(ledger: ExecutionLedger = ExecutionLedger()) {
        self.ledger = ledger
    }

    public func execute(
        event: ScheduledEvent,
        using adapter: any ProviderAdapter
    ) async throws -> ExecutionAttemptResult {
        let provider: ProviderID
        switch event.kind {
        case let .providerSession(value, _):
            provider = value
        }
        guard provider == adapter.id else {
            throw ProviderExecutionCoordinatorError.providerMismatch
        }

        let claimed = try await ledger.claim(eventID: event.id)
        guard claimed else {
            guard let record = try await ledger.record(for: event.id) else {
                throw ProviderExecutionCoordinatorError.missingLedgerRecord
            }
            return .skippedDuplicate(record)
        }

        let request = TriggerRequest(
            scheduleID: event.scheduleID,
            plannedFireDate: event.date,
            prompt: provider.minimalPrompt
        )

        do {
            let receipt = try await adapter.trigger(request)
            try await ledger.markConfirmed(eventID: event.id)
            return .confirmed(receipt)
        } catch {
            let message = userMessage(for: error)
            if failedBeforeSend(error) {
                try await ledger.markFailedBeforeSend(eventID: event.id)
                return .failedBeforeSend(message)
            }

            try await ledger.markDeliveryUnknown(eventID: event.id)
            return .deliveryUnknown(message)
        }
    }

    private func failedBeforeSend(_ error: any Error) -> Bool {
        if error is ProviderAdapterError {
            return true
        }

        guard let error = error as? ClaudeRoutineError else { return false }
        switch error {
        case .invalidEndpoint,
             .missingCredential,
             .invalidCredential,
             .promptTooLong,
             .routinePausedOrInvalid,
             .accessDenied,
             .routineNotFound,
             .usageLimitReached:
            return true
        case .serviceUnavailable, .requestFailed, .invalidResponse:
            return false
        }
    }

    private func userMessage(for error: any Error) -> String {
        if let error = error as? ClaudeRoutineError {
            return error.userMessage
        }
        if error is ProviderAdapterError {
            return "Live execution is not configured."
        }
        return "Wakebar could not determine whether the provider received the request."
    }

}
