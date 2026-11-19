import Foundation
import Network

/// Observes network reachability so the app can retry address lookups for spots
/// that were saved offline, once connectivity returns.
@Observable
final class NetworkMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "alpacas.InstaMapPin.NetworkMonitor")

    private(set) var isConnected = true

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor in
                self?.isConnected = connected
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
