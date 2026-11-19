import Foundation
import SwiftData

/// Shared SwiftData container so the app UI and the Siri App Intent read and
/// write the same on-device store.
enum SpotStore {
    static let container: ModelContainer = {
        do {
            return try ModelContainer(for: Spot.self)
        } catch {
            fatalError("Could not create the InstaMapPin data store: \(error)")
        }
    }()

    /// Returns the distinct tags currently in use, most-recent first.
    @MainActor
    static func existingTags() -> [String] {
        let context = container.mainContext
        var descriptor = FetchDescriptor<Spot>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.propertiesToFetch = [\.tag]
        guard let spots = try? context.fetch(descriptor) else { return [] }

        var seen = Set<String>()
        var result: [String] = []
        for spot in spots {
            let key = spot.tag.lowercased()
            if !key.isEmpty, !seen.contains(key) {
                seen.insert(key)
                result.append(spot.tag)
            }
        }
        return result
    }
}
