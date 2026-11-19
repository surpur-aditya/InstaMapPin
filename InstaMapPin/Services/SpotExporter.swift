import Foundation

/// Pure functions that render all spots to CSV or GPX text. Kept UI-free so the
/// output format can be unit-tested directly.
enum SpotExporter {
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func csv(from spots: [Spot]) -> String {
        let header = "id,createdAt,latitude,longitude,horizontalAccuracy,tag,note,address,weatherSummary"
        let rows = spots.map { spot in
            [
                spot.id.uuidString,
                isoFormatter.string(from: spot.createdAt),
                String(spot.latitude),
                String(spot.longitude),
                String(spot.horizontalAccuracy),
                escapeCSV(spot.tag),
                escapeCSV(spot.note ?? ""),
                escapeCSV(spot.address ?? ""),
                escapeCSV(spot.weatherSummary ?? "")
            ].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }

    static func gpx(from spots: [Spot]) -> String {
        let waypoints = spots.map { spot in
            var lines = ["""
              <wpt lat="\(spot.latitude)" lon="\(spot.longitude)">
                <time>\(isoFormatter.string(from: spot.createdAt))</time>
                <name>\(escapeXML(spot.tag))</name>
            """]
            if let note = spot.note, !note.isEmpty {
                lines.append("    <desc>\(escapeXML(note))</desc>")
            }
            lines.append("  </wpt>")
            return lines.joined(separator: "\n")
        }

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="InstaMapPin" xmlns="http://www.topografix.com/GPX/1/1">
        \(waypoints.joined(separator: "\n"))
        </gpx>
        """
    }

    private static func escapeCSV(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else {
            return value
        }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func escapeXML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
