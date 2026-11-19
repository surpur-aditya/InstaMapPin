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

    /// Returns the distinct spot names currently in use, most-recent first.
    @MainActor
    static func existingNames() -> [String] {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Spot>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        guard let spots = try? context.fetch(descriptor) else { return [] }

        var seen = Set<String>()
        var result: [String] = []
        for spot in spots {
            let key = spot.name.lowercased()
            if !key.isEmpty, !seen.contains(key) {
                seen.insert(key)
                result.append(spot.name)
            }
        }
        return result
    }

    /// Returns the distinct category tags currently in use, most-recent first.
    @MainActor
    static func existingCategories() -> [String] {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Spot>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        guard let spots = try? context.fetch(descriptor) else { return [] }

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
}
