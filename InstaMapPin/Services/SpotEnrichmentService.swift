import AppIntents
import CoreLocation
import Foundation
import MapKit
import SwiftData

/// Best-effort, fire-and-forget enrichment that runs *after* a spot is saved:
/// reverse geocodes an address, and — when the user didn't supply them — derives
/// a name (street / area / city / POI like "Stuttgart Airport") and a category
/// tag from the place's point-of-interest type. It never throws to the caller
/// and never blocks capture. If the device is offline the spot keeps
/// `needsAddressLookup` set, so `syncPending()` can fill it in once online.
@MainActor
enum SpotEnrichmentService {
    struct Lookup {
        var address: String?
        var suggestedName: String?
        var suggestedCategory: String?
        var didResolve: Bool
    }

    static func enrich(spotID: UUID, latitude: Double, longitude: Double) async {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let lookup = await reverseGeocode(location)
        apply(spotID: spotID, lookup: lookup)
    }

    /// Re-attempts lookups for every spot still awaiting one.
    static func syncPending() async {
        let context = SpotStore.container.mainContext
        let descriptor = FetchDescriptor<Spot>(predicate: #Predicate { $0.needsAddressLookup })
        guard let pending = try? context.fetch(descriptor), !pending.isEmpty else { return }
        for spot in pending {
            await enrich(spotID: spot.id, latitude: spot.latitude, longitude: spot.longitude)
        }
    }

    /// Maps a MapKit point-of-interest category to a short, human tag, reusing an
    /// existing tag's spelling when one already matches.
    static func category(for poi: MKPointOfInterestCategory?, existing: [String]) -> String? {
        guard let label = Self.label(for: poi) else { return nil }
        if let match = existing.first(where: { $0.lowercased() == label.lowercased() }) {
            return match
        }
        return label
    }

    // MARK: - Geocoding

    private static func reverseGeocode(_ location: CLLocation) async -> Lookup {
        guard let request = MKReverseGeocodingRequest(location: location) else {
            return Lookup(address: nil, suggestedName: nil, suggestedCategory: nil, didResolve: true)
        }
        do {
            let mapItems = try await request.mapItems
            guard let item = mapItems.first else {
                return Lookup(address: nil, suggestedName: nil, suggestedCategory: nil, didResolve: true)
            }
            let address = item.address?.shortAddress ?? item.address?.fullAddress
            let suggestedName = item.name ?? address
            let suggestedCategory = Self.category(for: item.pointOfInterestCategory, existing: SpotStore.existingCategories())
            return Lookup(address: address, suggestedName: suggestedName, suggestedCategory: suggestedCategory, didResolve: true)
        } catch {
            return Lookup(address: nil, suggestedName: nil, suggestedCategory: nil, didResolve: false)
        }
    }

    private static func apply(spotID: UUID, lookup: Lookup) {
        let context = SpotStore.container.mainContext
        let descriptor = FetchDescriptor<Spot>(predicate: #Predicate { $0.id == spotID })
        guard let spot = try? context.fetch(descriptor).first else { return }

        if let address = lookup.address, !address.isEmpty {
            spot.address = address
        }
        if spot.name.isEmpty, let name = lookup.suggestedName, !name.isEmpty {
            spot.name = name
        }
        if spot.categories.isEmpty, let category = lookup.suggestedCategory {
            spot.categories = [category]
        }
        if lookup.didResolve {
            spot.needsAddressLookup = false
        }
        try? context.save()
        SpotIndexer.index(spot)
        InstaMapPinShortcuts.updateAppShortcutParameters()
    }

    // MARK: - POI mapping

    private static func label(for poi: MKPointOfInterestCategory?) -> String? {
        guard let poi else { return nil }
        switch poi {
        case .airport: return "Airport"
        case .parking: return "Parking"
        case .foodMarket: return "Supermarket"
        case .gasStation: return "Gas Station"
        case .restaurant: return "Restaurant"
        case .cafe: return "Cafe"
        case .hotel: return "Hotel"
        case .hospital: return "Hospital"
        case .pharmacy: return "Pharmacy"
        case .store: return "Store"
        case .bank, .atm: return "Bank"
        case .school, .university: return "School"
        case .park: return "Park"
        case .beach: return "Beach"
        case .publicTransport: return "Transit"
        case .evCharger: return "EV Charger"
        default: return nil
        }
    }
}
