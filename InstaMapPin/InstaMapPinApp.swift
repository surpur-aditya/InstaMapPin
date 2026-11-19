import SwiftUI
import SwiftData

@main
struct InstaMapPinApp: App {
    private let locationManager = LocationManager()
    private let networkMonitor = NetworkMonitor()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(locationManager)
                .environment(networkMonitor)
        }
        .modelContainer(SpotStore.container)
    }
}
