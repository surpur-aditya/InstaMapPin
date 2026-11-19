import CoreLocation
import Foundation

/// Extracts a coordinate from a pasted map link or raw "lat,lon" text.
/// Supports Apple Maps (`ll=`, `q=`, `daddr=`), Google Maps (`query=`,
/// `destination=`, `@lat,lon`), and a plain "lat, lon" string.
enum MapLinkParser {
    static func coordinate(from text: String) -> CLLocationCoordinate2D? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Plain "lat, lon"
        if let coordinate = parsePair(trimmed) {
            return coordinate
        }

        guard let components = URLComponents(string: trimmed) else { return nil }
        let queryItems = components.queryItems ?? []

        // Query-parameter based links (Apple + Google)
        for key in ["ll", "query", "destination", "daddr", "q", "sll"] {
            if let value = queryItems.first(where: { $0.name == key })?.value,
               let coordinate = parsePair(value) {
                return coordinate
            }
        }

        // Google "@lat,lon,zoom" style embedded in the path
        if let atRange = trimmed.range(of: "@") {
            let afterAt = String(trimmed[atRange.upperBound...])
            if let coordinate = parsePair(afterAt) {
                return coordinate
            }
        }

        return nil
    }

    /// Parses the first "lat,lon" pair found at the start of the string.
    private static func parsePair(_ string: String) -> CLLocationCoordinate2D? {
        let cleaned = string.trimmingCharacters(in: .whitespaces)
        let parts = cleaned.split(separator: ",")
        guard parts.count >= 2,
              let lat = Double(parts[0].trimmingCharacters(in: .whitespaces)),
              let lon = Double(parts[1].trimmingCharacters(in: .whitespaces)),
              (-90...90).contains(lat),
              (-180...180).contains(lon) else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}
