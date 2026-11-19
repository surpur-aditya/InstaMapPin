import CoreLocation
import CoreSpotlight
import SwiftUI
import SwiftData

struct SpotListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LocationManager.self) private var locationManager
    @Environment(NetworkMonitor.self) private var networkMonitor

    @Query(sort: \Spot.createdAt, order: .reverse)
    private var spots: [Spot]

    @State private var addMode: AddSpotMode?
    @State private var showSettings = false
    @State private var searchText = ""
    @State private var isSearchPresented = false
    @State private var selectedCategory: String?
    @State private var navigationPath: [Spot] = []
    @State private var isQuickPinning = false
    @State private var quickPinError: String?

    /// Distinct categories across all spots, for the filter chips.
    private var allCategories: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for spot in spots {
            for category in spot.categories {
                let key = category.lowercased()
                if !seen.contains(key) {
                    seen.insert(key)
                    result.append(category)
                }
            }
        }
        return result
    }

    private var filteredSpots: [Spot] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return spots.filter { spot in
            if let selectedCategory,
               !spot.categories.contains(where: { $0.lowercased() == selectedCategory.lowercased() }) {
                return false
            }
            guard !query.isEmpty else { return true }
            let haystack = ([spot.displayName, spot.note ?? "", spot.address ?? ""] + spot.categories)
                .joined(separator: " ")
                .lowercased()
            return haystack.contains(query)
        }
    }

    private var groupedSpots: [(key: Date, spots: [Spot])] {
        let calendar = Calendar.current
        let dict = Dictionary(grouping: filteredSpots) { spot in
            calendar.startOfDay(for: spot.createdAt)
        }
        return dict.keys.sorted(by: >).map { day in (key: day, spots: dict[day]!) }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if spots.isEmpty {
                    emptyState
                } else {
                    spotList
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
            .navigationTitle("InstaMapPin")
            .navigationDestination(for: Spot.self) { spot in
                SpotDetailView(spot: spot)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    addMenu
                }
            }
            .sheet(item: $addMode) { mode in
                AddSpotSheet(mode: mode)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .alert("Couldn't Pin", isPresented: Binding(
                get: { quickPinError != nil },
                set: { if !$0 { quickPinError = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(quickPinError ?? "")
            }
            .onAppear {
                if locationManager.authorizationStatus == .notDetermined {
                    locationManager.requestWhenInUseAuthorization()
                }
                locationManager.startUpdates()
                SpotIndexer.reindexAll(spots)
                Task { await SpotEnrichmentService.syncPending() }
            }
            .onDisappear {
                locationManager.stopUpdates()
            }
            .onChange(of: locationManager.authorizationStatus) { _, _ in
                locationManager.startUpdates()
            }
            .onChange(of: networkMonitor.isConnected) { _, connected in
                if connected {
                    Task { await SpotEnrichmentService.syncPending() }
                }
            }
            .onContinueUserActivity(CSSearchableItemActionType) { activity in
                openSpotFromSpotlight(activity)
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button {
                Task { await quickPin() }
            } label: {
                HStack(spacing: 8) {
                    if isQuickPinning {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.headline)
                    }
                    Text(isQuickPinning ? "Pinning…" : "Pin Current Location")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(isQuickPinning)
            .accessibilityLabel("Pin current location")

            Button {
                isSearchPresented = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 56, height: 56)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .accessibilityLabel("Search")
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var addMenu: some View {
        Menu {
            Button {
                addMode = .currentLocation
            } label: {
                Label("Pin Current Location", systemImage: "location.fill")
            }
            Button {
                addMode = .address
            } label: {
                Label("From Address", systemImage: "character.cursor.ibeam")
            }
            Button {
                addMode = .link
            } label: {
                Label("From Map Link", systemImage: "link")
            }
            Button {
                addMode = .coordinates
            } label: {
                Label("From Coordinates", systemImage: "scope")
            }
        } label: {
            Label("Add Spot", systemImage: "plus")
        }
    }

    private var spotList: some View {
        List {
            if !allCategories.isEmpty {
                categoryChips
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowSeparator(.hidden)
            }

            if filteredSpots.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(groupedSpots, id: \.key) { group in
                    Section(group.key.formatted(date: .long, time: .omitted)) {
                        ForEach(group.spots) { spot in
                            NavigationLink(value: spot) {
                                SpotRowView(spot: spot)
                            }
                        }
                        .onDelete { offsets in
                            deleteSpots(group.spots, at: offsets)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, isPresented: $isSearchPresented, prompt: "Search name, tag, note, or address")
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(allCategories, id: \.self) { category in
                    FilterChip(
                        title: category,
                        isSelected: selectedCategory?.lowercased() == category.lowercased()
                    ) {
                        selectedCategory = (selectedCategory?.lowercased() == category.lowercased()) ? nil : category
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Pins Yet", systemImage: "mappin.slash")
        } description: {
            Text("Tap Pin Current Location below, or say\n\"Hey Siri, InstaMapPin\"")
        }
    }

    private func quickPin() async {
        isQuickPinning = true
        defer { isQuickPinning = false }
        do {
            try await SpotCaptureService.capture(name: "", categories: [], note: nil, using: locationManager)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            quickPinError = error.localizedDescription
        }
    }

    private func deleteSpots(_ spots: [Spot], at offsets: IndexSet) {
        for index in offsets {
            let spot = spots[index]
            SpotIndexer.deindex(id: spot.id)
            modelContext.delete(spot)
        }
    }

    private func openSpotFromSpotlight(_ activity: NSUserActivity) {
        guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
              let uuid = UUID(uuidString: identifier),
              let spot = spots.first(where: { $0.id == uuid }) else {
            return
        }
        navigationPath = [spot]
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemFill))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

#Preview {
    let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let c = try! ModelContainer(for: Spot.self, configurations: config)
        let spot = Spot(name: "Home", latitude: 37.7749, longitude: -122.4194, horizontalAccuracy: 5, categories: ["Family"])
        c.mainContext.insert(spot)
        return c
    }()
    return SpotListView()
        .modelContainer(container)
        .environment(LocationManager())
        .environment(NetworkMonitor())
}
