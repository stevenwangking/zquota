import Foundation

protocol RateLimitStoreDelegate: AnyObject {
    func rateLimitStore(_ store: RateLimitStore, didUpdate state: RateLimitDisplayState)
}

final class RateLimitStore {
    weak var delegate: RateLimitStoreDelegate?

    private let client = ZCodeQuotaClient()
    private var timer: Timer?
    private var state = RateLimitDisplayState.initial
    private var refreshInFlight = false
    private var isStarted = false

    func start() {
        guard !isStarted else {
            refresh()
            return
        }
        isStarted = true

        refresh()
        startTimer()
    }

    func stop() {
        isStarted = false
        refreshInFlight = false
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        guard !refreshInFlight else {
            return
        }

        refreshInFlight = true
        state.isRefreshing = true
        state.errorMessage = nil
        publish()

        client.fetch { [weak self] result in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }

                self.refreshInFlight = false

                switch result {
                case .success(let snapshot):
                    // 刷新失败时保留旧额度数据，只更新错误信息
                    self.state.fiveHour = snapshot.fiveHour
                    self.state.weekly = snapshot.weekly
                    self.state.usage = snapshot.usage
                    self.state.isRefreshing = false
                    self.state.lastUpdated = Date()
                    self.state.errorMessage = nil
                case .failure(let error):
                    self.state.isRefreshing = false
                    self.state.errorMessage = error.localizedDescription
                }

                self.publish()
            }
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    private func publish() {
        delegate?.rateLimitStore(self, didUpdate: state)
    }
}
