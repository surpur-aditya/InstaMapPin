//
//  InstaMapPinTests.swift
//  InstaMapPinTests
//
//  Created by Aditya Surpur on 17.11.26.
//

import Testing
import CoreLocation
import MapKit
import Foundation
@testable import InstaMapPin

@MainActor
struct SpotModelTests {
    @Test func initTrimsName() {
        let spot = Spot(name: "  Henry Home  ", latitude: 1, longitude: 2, horizontalAccuracy: 5)
        #expect(spot.name == "Henry Home")
    }

    @Test func initSetsCoordinatesAndDefaults() {
        let spot = Spot(name: "Home", latitude: 37.7749, longitude: -122.4194, horizontalAccuracy: 8)
        #expect(spot.latitude == 37.7749)
        #expect(spot.longitude == -122.4194)
        #expect(spot.horizontalAccuracy == 8)
        #expect(spot.note == nil)
        #expect(spot.address == nil)
        #expect(spot.categories.isEmpty)
        #expect(spot.needsAddressLookup)
    }

    @Test func manualEntryFlaggedByNegativeAccuracy() {
        let spot = Spot(name: "Pasted", latitude: 0, longitude: 0, horizontalAccuracy: -1)
        #expect(spot.isManualEntry)
    }

    @Test func categoriesAreTrimmedDedupedAndNonEmpty() {
        let spot = Spot(
            name: "Shop",
            latitude: 0, longitude: 0, horizontalAccuracy: 0,
            categories: [" Supermarket ", "supermarket", "", "Groceries"]
        )
        #expect(spot.categories == ["Supermarket", "Groceries"])
    }

    @Test func distinctIdentifiers() {
        let a = Spot(name: "A", latitude: 0, longitude: 0, horizontalAccuracy: 0)
        let b = Spot(name: "B", latitude: 0, longitude: 0, horizontalAccuracy: 0)
        #expect(a.id != b.id)
    }

    @Test func displayNameUsesNameThenAddressThenPlaceholder() {
        let named = Spot(name: "Home", latitude: 0, longitude: 0, horizontalAccuracy: 0)
        #expect(named.displayName == "Home")

        let unnamed = Spot(name: "", latitude: 0, longitude: 0, horizontalAccuracy: -1, needsAddressLookup: false)
        unnamed.address = "5 Main St"
        #expect(unnamed.displayName == "5 Main St")

        let pending = Spot(name: "", latitude: 0, longitude: 0, horizontalAccuracy: 0)
        #expect(pending.displayName == "Dropped Pin")
    }
}

@MainActor
struct POITaggingTests {
    @Test func mapsKnownPointOfInterestToTag() {
        #expect(SpotEnrichmentService.category(for: .airport, existing: []) == "Airport")
        #expect(SpotEnrichmentService.category(for: .foodMarket, existing: []) == "Supermarket")
    }

    @Test func reusesExistingTagSpelling() {
        let tag = SpotEnrichmentService.category(for: .parking, existing: ["PARKING"])
        #expect(tag == "PARKING")
    }

    @Test func unknownCategoryReturnsNil() {
        #expect(SpotEnrichmentService.category(for: nil, existing: []) == nil)
    }
}

@MainActor
struct MapLinksTests {
    @Test func appleMapsURLIncludesCoordinatesAndEncodedName() {
        let url = MapLinks.appleMapsURL(latitude: 37.7749, longitude: -122.4194, name: "Henry Home")
        #expect(url?.absoluteString == "https://maps.apple.com/?ll=37.7749,-122.4194&q=Henry%20Home")
    }

    @Test func appleMapsURLEncodesSpecialCharacters() {
        let url = MapLinks.appleMapsURL(latitude: 1, longitude: 2, name: "Dad's & Mom's")
        let string = url?.absoluteString ?? ""
        #expect(!string.contains("Dad's & Mom's"))
        #expect(string.contains("q="))
    }

    @Test func googleMapsURLUsesQueryParameter() {
        let url = MapLinks.googleMapsURL(latitude: 10.5, longitude: -20.25)
        #expect(url?.absoluteString == "https://www.google.com/maps/search/?api=1&query=10.5,-20.25")
    }

    @Test func appleDirectionsURLRoutesToDestination() {
        let url = MapLinks.appleMapsDirectionsURL(latitude: 1.5, longitude: 2.5)
        #expect(url?.absoluteString == "https://maps.apple.com/?daddr=1.5,2.5&dirflg=d")
    }

    @Test func googleDirectionsURLRoutesToDestination() {
        let url = MapLinks.googleMapsDirectionsURL(latitude: 1.5, longitude: 2.5)
        #expect(url?.absoluteString == "https://www.google.com/maps/dir/?api=1&destination=1.5,2.5")
    }

    @Test func shareTextContainsBothLinks() {
        let text = MapLinks.shareText(latitude: 1, longitude: 2, name: "Office")
        #expect(text.contains("Office"))
        #expect(text.contains("https://maps.apple.com/"))
        #expect(text.contains("https://www.google.com/maps/search/"))
    }
}

@MainActor
struct MapLinkParserTests {
    @Test func parsesPlainLatLon() {
        let coordinate = MapLinkParser.coordinate(from: "37.7749, -122.4194")
        #expect(coordinate?.latitude == 37.7749)
        #expect(coordinate?.longitude == -122.4194)
    }

    @Test func parsesAppleMapsLink() {
        let coordinate = MapLinkParser.coordinate(from: "https://maps.apple.com/?ll=40.0,-73.0&q=Home")
        #expect(coordinate?.latitude == 40.0)
        #expect(coordinate?.longitude == -73.0)
    }

    @Test func parsesGoogleQueryLink() {
        let coordinate = MapLinkParser.coordinate(from: "https://www.google.com/maps/search/?api=1&query=10.5,20.5")
        #expect(coordinate?.latitude == 10.5)
        #expect(coordinate?.longitude == 20.5)
    }

    @Test func parsesGoogleAtStyleLink() {
        let coordinate = MapLinkParser.coordinate(from: "https://www.google.com/maps/@48.8584,2.2945,17z")
        #expect(coordinate?.latitude == 48.8584)
        #expect(coordinate?.longitude == 2.2945)
    }

    @Test func rejectsNonLocationText() {
        #expect(MapLinkParser.coordinate(from: "hello world") == nil)
        #expect(MapLinkParser.coordinate(from: "") == nil)
    }

    @Test func rejectsOutOfRangeCoordinates() {
        #expect(MapLinkParser.coordinate(from: "200, 999") == nil)
    }
}

@MainActor
struct SpotExporterTests {
    private func sampleSpots() -> [Spot] {
        let a = Spot(name: "Home", latitude: 37.7749, longitude: -122.4194, horizontalAccuracy: 5, categories: ["Family"])
        let b = Spot(name: "Cafe, Downtown", latitude: 40.0, longitude: -73.0, horizontalAccuracy: 10)
        b.note = "Great \"flat white\""
        return [a, b]
    }

    @Test func csvHasHeaderAndRowPerSpot() {
        let csv = SpotExporter.csv(from: sampleSpots())
        let lines = csv.split(separator: "\n")
        #expect(lines.count == 3) // header + 2 rows
        #expect(lines.first?.hasPrefix("id,createdAt,latitude,longitude") == true)
    }

    @Test func csvEscapesCommasAndQuotes() {
        let csv = SpotExporter.csv(from: sampleSpots())
        #expect(csv.contains("\"Cafe, Downtown\""))
        #expect(csv.contains("\"\"flat white\"\""))
    }

    @Test func csvOfEmptyListIsJustHeader() {
        let csv = SpotExporter.csv(from: [])
        #expect(csv == "id,createdAt,latitude,longitude,horizontalAccuracy,name,categories,note,address")
    }

    @Test func gpxContainsWaypointsAndCategories() {
        let gpx = SpotExporter.gpx(from: sampleSpots())
        #expect(gpx.contains("<gpx"))
        #expect(gpx.contains("lat=\"37.7749\" lon=\"-122.4194\""))
        #expect(gpx.contains("<name>Home</name>"))
        #expect(gpx.contains("<type>Family</type>"))
    }
}

@MainActor
struct SpotNameEntityTests {
    @Test func initTrimsAndLowercasesIdentifier() {
        let entity = SpotNameEntity(name: "  Henry Home  ")
        #expect(entity.name == "Henry Home")
        #expect(entity.id == "henry home")
    }

    @Test func matchingNamesAreCaseInsensitiveByIdentifier() {
        let a = SpotNameEntity(name: "HOME")
        let b = SpotNameEntity(name: "home")
        #expect(a.id == b.id)
    }
}
