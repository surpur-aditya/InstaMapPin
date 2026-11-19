import SwiftData
import SwiftUI

struct ContentView: View {
    var body: some View {
        SpotListView()
    }
}

#Preview {
    ContentView()
        .environment(LocationManager())
        .environment(NetworkMonitor())
        .modelContainer(for: Spot.self, inMemory: true)
}
