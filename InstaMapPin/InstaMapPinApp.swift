import SwiftUI
import SwiftData

@main
struct InstaMapPinApp: App {
    private let locationManager = LocationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(locationManager)
        }
        .modelContainer(for: Spot.self)
    }
}
