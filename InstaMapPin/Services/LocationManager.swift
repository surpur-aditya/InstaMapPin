import CoreLocation
import Foundation

enum LocationError: LocalizedError {
    case permissionDenied
    case timeout
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location access is off. Turn it on in Settings › Privacy & Security › Location Services › InstaMapPin."
        case .timeout:
            return "Couldn't get a location fix in time. Please try again."
        case .failed(let message):
            return message
        }
    }
}

@Observable
final class LocationManager: NSObject {
    private let clManager = CLLocationManager()

    private(set) var authorizationStatus: CLAuthorizationStatus

    /// The most recent location delivered while updates are running. Kept warm so
    /// a "quick pin" can save instantly instead of waiting for a fresh GPS fix.
    private(set) var lastLocation: CLLocation?

    // Continuations are only ever touched on the main actor (default isolation).
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var authContinuations: [CheckedContinuation<CLAuthorizationStatus, Never>] = []

    override init() {
        authorizationStatus = .notDetermined
        super.init()
        clManager.delegate = self
        clManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        authorizationStatus = clManager.authorizationStatus
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    /// Fire-and-forget request, used to surface the system prompt on first launch.
    func requestWhenInUseAuthorization() {
        guard authorizationStatus == .notDetermined else { return }
        clManager.requestWhenInUseAuthorization()
    }

    func requestAlwaysAuthorization() {
        clManager.requestAlwaysAuthorization()
    }

    /// Requests "When In Use" and waits for the user's response. If permission is
    /// already determined, returns the current status immediately.
    func ensureWhenInUseAuthorization() async -> CLAuthorizationStatus {
        guard authorizationStatus == .notDetermined else { return authorizationStatus }
        return await withCheckedContinuation { continuation in
            authContinuations.append(continuation)
            clManager.requestWhenInUseAuthorization()
        }
    }

    /// Keeps a recent location cached while the main screen is visible so pinning
    /// is instant. Safe to call repeatedly.
    func startUpdates() {
        guard isAuthorized else { return }
        clManager.startUpdatingLocation()
    }

    func stopUpdates() {
        clManager.stopUpdatingLocation()
    }

    /// Returns a location as fast as possible: the warm cached fix if it's recent,
    /// otherwise a single fresh request. Never blocks longer than `timeout`.
    func quickLocation(maxAge: TimeInterval = 120, timeout: Duration = .seconds(8)) async throws -> CLLocation {
        guard isAuthorized else { throw LocationError.permissionDenied }
        if let last = lastLocation,
           last.horizontalAccuracy >= 0,
           Date().timeIntervalSince(last.timestamp) < maxAge {
            return last
        }
        return try await captureLocation(timeout: timeout)
    }

    /// Requests a single location fix, racing the system against a timeout so the
    /// UI never spins forever. Caller must already hold location permission.
    func captureLocation(timeout: Duration = .seconds(12)) async throws -> CLLocation {
        guard isAuthorized else { throw LocationError.permissionDenied }

        let timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: timeout)
            guard !Task.isCancelled else { return }
            self?.resumeLocation(with: .failure(LocationError.timeout))
        }
        defer { timeoutTask.cancel() }

        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            clManager.requestLocation()
        }
    }

    private func resumeLocation(with result: Result<CLLocation, Error>) {
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil
        continuation.resume(with: result)
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor [weak self] in
            self?.lastLocation = location
            self?.resumeLocation(with: .success(location))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.resumeLocation(with: .failure(LocationError.failed(error.localizedDescription)))
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.authorizationStatus = status
            // Only resume waiters once the user has actually made a choice.
            if status != .notDetermined, !self.authContinuations.isEmpty {
                let waiters = self.authContinuations
                self.authContinuations.removeAll()
                for waiter in waiters {
                    waiter.resume(returning: status)
                }
            }
        }
    }
}
