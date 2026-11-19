import AppIntents
import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Spot.createdAt, order: .reverse) private var spots: [Spot]

    @State private var csvURL: URL?
    @State private var gpxURL: URL?
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                exportSection
                dataSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task(id: spots.count) { regenerateExports() }
            .confirmationDialog(
                "Delete all \(spots.count) saved pins? This cannot be undone.",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete All", role: .destructive) { deleteAll() }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    // MARK: - Sections

    private var exportSection: some View {
        Section {
            if spots.isEmpty {
                Text("No pins to export yet.")
                    .foregroundStyle(.secondary)
            } else {
                if let csvURL {
                    ShareLink(item: csvURL) {
                        Label("Export as CSV", systemImage: "tablecells")
                    }
                }
                if let gpxURL {
                    ShareLink(item: gpxURL) {
                        Label("Export as GPX", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    }
                }
            }
        } header: {
            Text("Export")
        } footer: {
            Text("Exports all \(spots.count) pins to a file you can share or save.")
        }
    }

    private var dataSection: some View {
        Section("Data") {
            Button("Delete All Data", role: .destructive) {
                showDeleteConfirm = true
            }
            .disabled(spots.isEmpty)
        }
    }

    // MARK: - Helpers

    private func regenerateExports() {
        let temp = FileManager.default.temporaryDirectory
        let csv = temp.appendingPathComponent("InstaMapPin-Spots.csv")
        let gpx = temp.appendingPathComponent("InstaMapPin-Spots.gpx")
        do {
            try SpotExporter.csv(from: spots).write(to: csv, atomically: true, encoding: .utf8)
            try SpotExporter.gpx(from: spots).write(to: gpx, atomically: true, encoding: .utf8)
            csvURL = csv
            gpxURL = gpx
        } catch {
            csvURL = nil
            gpxURL = nil
        }
    }

    private func deleteAll() {
        for spot in spots {
            modelContext.delete(spot)
        }
        try? modelContext.save()
        SpotIndexer.deleteAll()
        InstaMapPinShortcuts.updateAppShortcutParameters()
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: Spot.self, inMemory: true)
}
