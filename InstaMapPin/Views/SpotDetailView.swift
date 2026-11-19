import MapKit
import SwiftData
import SwiftUI

struct SpotDetailView: View {
    let spot: Spot

    @State private var isEditing = false
    @State private var nameDraft = ""
    @State private var categoriesDraft = ""
    @State private var noteDraft = ""

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
    }

    private var appleMapsURL: URL? {
        MapLinks.appleMapsURL(latitude: spot.latitude, longitude: spot.longitude, name: spot.name)
    }

    private var googleMapsURL: URL? {
        MapLinks.googleMapsURL(latitude: spot.latitude, longitude: spot.longitude)
    }

    private var shareText: String {
        MapLinks.shareText(latitude: spot.latitude, longitude: spot.longitude, name: spot.name)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                mapPreview
                infoSection
                actionButtons
            }
            .padding()
        }
        .navigationTitle(spot.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(isEditing ? "Done" : "Edit") {
                    if isEditing { saveEdits() } else { startEditing() }
                }
            }
        }
    }

    private var mapPreview: some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 400,
            longitudinalMeters: 400
        ))) {
            Marker(spot.name, coordinate: coordinate)
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var infoSection: some View {
        if isEditing {
            editFields
        } else {
            displayFields
        }
    }

    private var displayFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(spot.name, systemImage: "mappin")
                .font(.headline)
            if !spot.categories.isEmpty {
                categoryChips
            }
            if let note = spot.note, !note.isEmpty {
                Label(note, systemImage: "note.text")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let address = spot.address {
                Label(address, systemImage: "location")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if spot.needsAddressLookup {
                Label("Finding address…", systemImage: "location")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Label(accuracyText, systemImage: "scope")
                .font(.caption)
                .foregroundStyle(.secondary)
            Label(spot.createdAt.formatted(date: .long, time: .shortened), systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(spot.categories, id: \.self) { category in
                    Text(category)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var editFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            labeledField("Name", placeholder: "Name", text: $nameDraft)
            labeledField("Tags (comma-separated)", placeholder: "Supermarket, Groceries", text: $categoriesDraft)
            VStack(alignment: .leading, spacing: 4) {
                Text("Note")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Note (optional)", text: $noteDraft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
            }
        }
    }

    private func labeledField(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            NavigateButton(latitude: spot.latitude, longitude: spot.longitude, name: spot.name)

            HStack(spacing: 10) {
                if let url = appleMapsURL {
                    Link(destination: url) {
                        Label("Apple Maps", systemImage: "map.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.accentColor.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                if let url = googleMapsURL {
                    Link(destination: url) {
                        Label("Google Maps", systemImage: "map")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.accentColor.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            ShareLink(item: shareText) {
                Label("Share Location", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var accuracyText: String {
        if spot.isManualEntry {
            return String(format: "%.5f, %.5f  ·  Manual entry", spot.latitude, spot.longitude)
        }
        return String(format: "%.5f, %.5f  ±%.0f m", spot.latitude, spot.longitude, spot.horizontalAccuracy)
    }

    private func startEditing() {
        nameDraft = spot.name
        categoriesDraft = spot.categories.joined(separator: ", ")
        noteDraft = spot.note ?? ""
        isEditing = true
    }

    private func saveEdits() {
        let trimmedName = nameDraft.trimmingCharacters(in: .whitespaces)
        if !trimmedName.isEmpty {
            spot.name = trimmedName
        }
        spot.categories = Spot.normalizedCategories(categoriesDraft.split(separator: ",").map(String.init))
        let trimmedNote = noteDraft.trimmingCharacters(in: .whitespaces)
        spot.note = trimmedNote.isEmpty ? nil : trimmedNote
        SpotIndexer.index(spot)
        InstaMapPinShortcuts.updateAppShortcutParameters()
        isEditing = false
    }
}

#Preview {
    spotDetailPreview()
}

private func spotDetailPreview() -> some View {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Spot.self, configurations: config)
    let spot = Spot(name: "Henry Home", latitude: 37.7749, longitude: -122.4194, horizontalAccuracy: 8, categories: ["Family", "Favorite"])
    spot.note = "Parked near the red building"
    spot.address = "1 Apple Park Way, Cupertino, CA"
    container.mainContext.insert(spot)
    return NavigationStack {
        SpotDetailView(spot: spot)
    }
    .modelContainer(container)
}
