import AppIntents
import Foundation

/// An App Entity representing a spot name. It is backed by the names already used
/// in the app so Siri can recognise them, while still allowing brand-new names
/// (spoken for the first time) to be created on the fly.
struct SpotNameEntity: AppEntity {
    var id: String          // lowercased name, used as the stable identifier
    var name: String        // the name as the user typed / spoke it

    init(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        self.id = trimmed.lowercased()
        self.name = trimmed
    }

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Name")

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static let defaultQuery = SpotNameQuery()
}

/// String query so Siri can match a spoken phrase to an existing name, and so a
/// new name can be created when nothing matches.
struct SpotNameQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [SpotNameEntity] {
        let existing = await SpotStore.existingNames()
        return identifiers.map { identifier in
            if let match = existing.first(where: { $0.lowercased() == identifier }) {
                return SpotNameEntity(name: match)
            }
            return SpotNameEntity(id: identifier, name: identifier)
        }
    }

    func entities(matching string: String) async throws -> [SpotNameEntity] {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        let existing = await SpotStore.existingNames()
        var results = existing
            .filter { $0.localizedCaseInsensitiveContains(trimmed) }
            .map { SpotNameEntity(name: $0) }

        if !trimmed.isEmpty, !results.contains(where: { $0.id == trimmed.lowercased() }) {
            results.append(SpotNameEntity(name: trimmed))
        }
        return results
    }

    func suggestedEntities() async throws -> [SpotNameEntity] {
        await SpotStore.existingNames().map { SpotNameEntity(name: $0) }
    }
}
