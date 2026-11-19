import CoreLocation
import SwiftUI
import SwiftData
import UIKit

enum AddSpotMode: String, CaseIterable, Identifiable {
    case currentLocation
    case address
    case link
    case coordinates

    var id: String { rawValue }

    var label: String {
        switch self {
        case .currentLocation: return "Here"
        case .address: return "Address"
        case .link: return "Link"
        case .coordinates: return "Coords"
        }
    }
}

/// Unified sheet for adding a spot: at the current location, by typing an
/// address, by pasting a map link, or by entering coordinates. The name and
/// tags are optional — they get auto-filled from the location when left blank.
struct AddSpotSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(LocationManager.self) private var locationManager

    @State private var mode: AddSpotMode
    @State private var name = ""
    @State private var categoriesText = ""
    @State private var note = ""
    @State private var addressQuery = ""
    @State private var linkText = ""
    @State private var latitudeText = ""
    @State private var longitudeText = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showSettingsLink = false

    init(mode: AddSpotMode = .currentLocation) {
        _mode = State(initialValue: mode)
    }

    private var categories: [String] {
        categoriesText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private var enteredCoordinate: CLLocationCoordinate2D? {
        guard let lat = Double(latitudeText.trimmingCharacters(in: .whitespaces)),
              let lon = Double(longitudeText.trimmingCharacters(in: .whitespaces)),
              (-90...90).contains(lat), (-180...180).contains(lon) else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private var canSave: Bool {
        switch mode {
        case .currentLocation: return true
        case .address: return !addressQuery.trimmingCharacters(in: .whitespaces).isEmpty
        case .link: return !linkText.trimmingCharacters(in: .whitespaces).isEmpty
        case .coordinates: return enteredCoordinate != nil
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Source", selection: $mode) {
                        ForEach(AddSpotMode.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                sourceSection

                Section {
                    TextField("Auto-filled from location if left blank", text: $name)
                        .autocorrectionDisabled()
                } header: {
                    Text("Name (optional)")
                }

                Section {
                    TextField("Supermarket, Groceries", text: $categoriesText)
                        .autocorrectionDisabled()
                } header: {
                    Text("Tags (optional)")
                } footer: {
                    Text("Comma-separated. Auto-suggested from the place when blank.")
                }

                Section("Note (optional)") {
                    TextField("Any details…", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.callout)
                        if showSettingsLink {
                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    openURL(url)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Spot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await save() } }
                            .disabled(!canSave)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var sourceSection: some View {
        switch mode {
        case .currentLocation:
            Section {
                Label("Uses your current location", systemImage: "location.fill")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        case .address:
            Section("Address") {
                TextField("Street, city, or place", text: $addressQuery, axis: .vertical)
                    .lineLimit(1...3)
            }
        case .link:
            Section {
                TextField("Paste a map link", text: $linkText, axis: .vertical)
                    .lineLimit(1...3)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button {
                    if let pasted = UIPasteboard.general.string {
                        linkText = pasted
                    }
                } label: {
                    Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                }
            } header: {
                Text("Map Link")
            } footer: {
                Text("An Apple Maps or Google Maps link that contains coordinates.")
            }
        case .coordinates:
            Section {
                TextField("Latitude (e.g. 48.6899)", text: $latitudeText)
                    .keyboardType(.numbersAndPunctuation)
                    .autocorrectionDisabled()
                TextField("Longitude (e.g. 9.2210)", text: $longitudeText)
                    .keyboardType(.numbersAndPunctuation)
                    .autocorrectionDisabled()
            } header: {
                Text("Coordinates")
            } footer: {
                Text("Decimal degrees. Latitude −90…90, longitude −180…180.")
            }
        }
    }

    private func save() async {
        errorMessage = nil
        showSettingsLink = false
        isSaving = true
        defer { isSaving = false }

        do {
            switch mode {
            case .currentLocation:
                try await SpotCaptureService.capture(
                    name: name, categories: categories, note: note, using: locationManager
                )
            case .address:
                try await SpotCaptureService.addFromAddress(
                    addressQuery, name: name, categories: categories, note: note
                )
            case .link:
                try SpotCaptureService.addFromLink(
                    linkText, name: name, categories: categories, note: note
                )
            case .coordinates:
                guard let coordinate = enteredCoordinate else { return }
                SpotCaptureService.addFromCoordinates(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    name: name, categories: categories, note: note
                )
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch LocationError.permissionDenied {
            errorMessage = LocationError.permissionDenied.errorDescription
            showSettingsLink = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    AddSpotSheet()
        .environment(LocationManager())
        .modelContainer(for: Spot.self, inMemory: true)
}
