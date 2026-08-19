actor PhoneCompanionOperationQueue {
    private var tail = Task<Void, Never> {}

    func run<Result: Sendable>(
        _ operation: @escaping @Sendable () async -> Result
    ) async -> Result {
        let precedingTask = tail
        let task = Task {
            await precedingTask.value
            return await operation()
        }

        tail = Task {
            _ = await task.value
        }
        return await task.value
    }
}
