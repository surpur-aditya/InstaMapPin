import Foundation
import SwiftData

@Model
final class Spot {
    var id: UUID
    var createdAt: Date
    var latitude: Double
    var longitude: Double
    /// Horizontal accuracy in metres, or a negative value for manually-added spots.
    var horizontalAccuracy: Double
    /// The main title of the spot (e.g. "Henry Home"). Renamed from `tag`.
    @Attribute(originalName: "tag") var name: String
    /// Filterable category tags (e.g. ["Supermarket", "Groceries"]).
    var categories: [String]
    var note: String?
    var address: String?
    /// True when the address still needs to be reverse geocoded (e.g. saved offline).
    var needsAddressLookup: Bool

    init(
        name: String,
        latitude: Double,
        longitude: Double,
        horizontalAccuracy: Double,
        categories: [String] = [],
        needsAddressLookup: Bool = true
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracy = horizontalAccuracy
        self.name = name.trimmingCharacters(in: .whitespaces)
        self.categories = Spot.normalizedCategories(categories)
        self.needsAddressLookup = needsAddressLookup
    }

    var isManualEntry: Bool { horizontalAccuracy < 0 }

    /// Trims, removes blanks, and de-duplicates categories case-insensitively
    /// while preserving the original order and casing of the first occurrence.
    static func normalizedCategories(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in raw {
            let trimmed = value.trimmingCharacters(in: .whitespaces)
            let key = trimmed.lowercased()
            if !trimmed.isEmpty, !seen.contains(key) {
                seen.insert(key)
                result.append(trimmed)
            }
        }
        return result
    }
}
