import SwiftUI

struct ContentView: View {
    var body: some View {
        SpotListView()
    }
}

#Preview {
    ContentView()
        .environment(LocationManager())
        .modelContainer(for: Spot.self, inMemory: true)
}
