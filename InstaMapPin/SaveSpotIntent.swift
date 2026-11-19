import AppIntents
import CoreLocation
import Foundation

/// Saves the current location with a name (and optional category + note). Runs
/// without opening the app so it can be triggered hands-free with Siri.
struct SaveSpotIntent: AppIntent {
    static let title: LocalizedStringResource = "Save a Pin"
    static let description = IntentDescription(
        "Saves your current location with a name so you can find it later."
    )
    static let openAppWhenRun = false

    // Optional: when omitted, the name is auto-derived from the location
    // (street / area / city / place), so hands-free capture needs no name.
    @Parameter(title: "Name")
    var name: SpotNameEntity?

    @Parameter(title: "Category")
    var category: String?

    @Parameter(title: "Note")
    var note: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Save a pin as \(\.$name)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let locationManager = LocationManager()
        let categories = category.map { [$0] } ?? []

        do {
            let spot = try await SpotCaptureService.capture(
                name: name?.name ?? "",
                categories: categories,
                note: note,
                using: locationManager
            )
            return .result(dialog: "Saved \(spot.displayName).")
        } catch LocationError.permissionDenied {
            return .result(dialog: """
            I can't save a pin because location access is off. \
            Open InstaMapPin, then turn on location in Settings.
            """)
        } catch LocationError.timeout {
            return .result(dialog: "I couldn't get a location fix. Please try again.")
        }
    }
}
