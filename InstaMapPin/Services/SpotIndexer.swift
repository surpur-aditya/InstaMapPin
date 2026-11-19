import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

/// Indexes spots with CoreSpotlight so a system search for a tag ("Henry Home")
/// surfaces the saved pin.
enum SpotIndexer {
    static let domainIdentifier = "alpacas.InstaMapPin.spots"

    static func index(_ spot: Spot) {
        CSSearchableIndex.default().indexSearchableItems([searchableItem(for: spot)])
    }

    static func reindexAll(_ spots: [Spot]) {
        let items = spots.map(searchableItem(for:))
        guard !items.isEmpty else { return }
        CSSearchableIndex.default().indexSearchableItems(items)
    }

    static func deindex(id: UUID) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [id.uuidString])
    }

    static func deleteAll() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domainIdentifier])
    }

    private static func searchableItem(for spot: Spot) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .text)
        attributes.title = spot.tag
        attributes.contentDescription = [spot.note, spot.address]
            .compactMap { $0 }
            .joined(separator: " · ")
        attributes.keywords = [spot.tag]
        attributes.latitude = NSNumber(value: spot.latitude)
        attributes.longitude = NSNumber(value: spot.longitude)

        return CSSearchableItem(
            uniqueIdentifier: spot.id.uuidString,
            domainIdentifier: domainIdentifier,
            attributeSet: attributes
        )
    }
}
