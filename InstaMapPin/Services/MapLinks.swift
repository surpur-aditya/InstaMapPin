import Foundation

/// Builds the Apple / Google Maps deep links (show + directions) and the
/// shareable text for a spot. Kept UI-free so it can be unit-tested directly.
enum MapLinks {

    // MARK: - Show a location

    static func appleMapsURL(latitude: Double, longitude: Double, name: String) -> URL? {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        return URL(string: "https://maps.apple.com/?ll=\(latitude),\(longitude)&q=\(encoded)")
    }

    static func googleMapsURL(latitude: Double, longitude: Double) -> URL? {
        URL(string: "https://www.google.com/maps/search/?api=1&query=\(latitude),\(longitude)")
    }

    // MARK: - Directions from current location

    static func appleMapsDirectionsURL(latitude: Double, longitude: Double) -> URL? {
        // Omitting `saddr` makes Apple Maps route from the current location.
        URL(string: "https://maps.apple.com/?daddr=\(latitude),\(longitude)&dirflg=d")
    }

    static func googleMapsDirectionsURL(latitude: Double, longitude: Double) -> URL? {
        URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(latitude),\(longitude)")
    }

    // MARK: - Sharing

    static func shareText(latitude: Double, longitude: Double, name: String) -> String {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        return """
        \(name)
        Apple Maps: https://maps.apple.com/?ll=\(latitude),\(longitude)&q=\(encoded)
        Google Maps: https://www.google.com/maps/search/?api=1&query=\(latitude),\(longitude)
        """
    }
}
