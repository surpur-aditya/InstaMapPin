import AppIntents
import CoreLocation
import Foundation
import MapKit
import SwiftData

enum AddSpotError: LocalizedError {
    case invalidLink
    case addressNotFound

    var errorDescription: String? {
        switch self {
        case .invalidLink:
            return "Couldn't find a location in that link. Paste an Apple or Google Maps link, or \"latitude, longitude\"."
        case .addressNotFound:
            return "Couldn't find that address. Try adding more detail."
        }
    }
}

/// Single code path for creating spots, shared by the in-app add flows and the
/// Siri `SaveSpotIntent`.
@MainActor
enum SpotCaptureService {

    /// Saves a spot at the device's current location.
    @discardableResult
    static func capture(
        name: String,
        categories: [String],
        note: String?,
        using locationManager: LocationManager
    ) async throws -> Spot {
        let status = await locationManager.ensureWhenInUseAuthorization()
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            throw LocationError.permissionDenied
        }
        let location = try await locationManager.captureLocation()
        return insert(
            name: name,
            categories: categories,
            note: note,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            horizontalAccuracy: location.horizontalAccuracy,
            address: nil,
            needsAddressLookup: true
        )
    }

    /// Saves a spot parsed from a pasted map link or "lat, lon" text.
    @discardableResult
    static func addFromLink(
        _ text: String,
        name: String,
        categories: [String],
        note: String?
    ) throws -> Spot {
        guard let coordinate = MapLinkParser.coordinate(from: text) else {
            throw AddSpotError.invalidLink
        }
        return insert(
            name: name,
            categories: categories,
            note: note,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            horizontalAccuracy: -1,
            address: nil,
            needsAddressLookup: true
        )
    }

    /// Saves a spot by forward-geocoding a typed address.
    @discardableResult
    static func addFromAddress(
        _ query: String,
        name: String,
        categories: [String],
        note: String?
    ) async throws -> Spot {
        guard let request = MKGeocodingRequest(addressString: query),
              let mapItem = (try? await request.mapItems)?.first else {
            throw AddSpotError.addressNotFound
        }
        let coordinate = mapItem.location.coordinate
        let address = mapItem.address?.shortAddress ?? mapItem.address?.fullAddress
        return insert(
            name: name,
            categories: categories,
            note: note,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            horizontalAccuracy: -1,
            address: address,
            needsAddressLookup: address == nil
        )
    }

    // MARK: - Core

    @discardableResult
    static func insert(
        name: String,
        categories: [String],
        note: String?,
        latitude: Double,
        longitude: Double,
        horizontalAccuracy: Double,
        address: String?,
        needsAddressLookup: Bool
    ) -> Spot {
        let spot = Spot(
            name: name,
            latitude: latitude,
            longitude: longitude,
            horizontalAccuracy: horizontalAccuracy,
            categories: categories,
            needsAddressLookup: needsAddressLookup
        )
        if let trimmed = note?.trimmingCharacters(in: .whitespaces), !trimmed.isEmpty {
            spot.note = trimmed
        }
        spot.address = address

        let context = SpotStore.container.mainContext
        context.insert(spot)
        try? context.save()

        SpotIndexer.index(spot)
        InstaMapPinShortcuts.updateAppShortcutParameters()

        if needsAddressLookup {
            let id = spot.id
            Task {
                await SpotEnrichmentService.enrich(spotID: id, latitude: latitude, longitude: longitude)
            }
        }

        return spot
    }
}
