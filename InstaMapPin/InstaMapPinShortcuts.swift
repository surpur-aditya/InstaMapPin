import AppIntents

/// Registers the Siri phrases for saving a pin. Every phrase must contain the
/// app name (an Apple requirement for zero-setup App Shortcuts), so the natural
/// "Save location as …" style is phrased as "… in InstaMapPin as …".
struct InstaMapPinShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SaveSpotIntent(),
            phrases: [
                "\(.applicationName)",
                "\(.applicationName) as \(\.$name)",
                "Save a pin in \(.applicationName) as \(\.$name)",
                "Save location in \(.applicationName) as \(\.$name)",
                "Save my location in \(.applicationName) as \(\.$name)",
                "Mark location in \(.applicationName) as \(\.$name)",
                "Drop a pin in \(.applicationName) as \(\.$name)"
            ],
            shortTitle: "Save a Pin",
            systemImageName: "mappin.and.ellipse"
        )
    }
}
