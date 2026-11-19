import MapKit
import SwiftUI

/// A small, static map preview for list rows, rendered with `MKMapSnapshotter`
/// and cached so scrolling stays smooth.
struct MapThumbnail: View {
    let latitude: Double
    let longitude: Double
    var size: CGFloat = 58

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color(.secondarySystemFill))
            }
            Image(systemName: "mappin.circle.fill")
                .font(.body)
                .foregroundStyle(.red)
                .shadow(radius: 1)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .task(id: "\(latitude),\(longitude),\(size)") {
            image = await MapSnapshotCache.shared.snapshot(
                latitude: latitude,
                longitude: longitude,
                size: CGSize(width: size, height: size)
            )
        }
        .accessibilityHidden(true)
    }
}

@MainActor
final class MapSnapshotCache {
    static let shared = MapSnapshotCache()
    private let cache = NSCache<NSString, UIImage>()

    func snapshot(latitude: Double, longitude: Double, size: CGSize) async -> UIImage? {
        let key = "\(latitude),\(longitude),\(size.width)x\(size.height)" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            latitudinalMeters: 350,
            longitudinalMeters: 350
        )
        options.size = size

        let snapshotter = MKMapSnapshotter(options: options)
        let image: UIImage? = await withCheckedContinuation { continuation in
            snapshotter.start(with: .main) { snapshot, _ in
                continuation.resume(returning: snapshot?.image)
            }
        }
        if let image {
            cache.setObject(image, forKey: key)
        }
        return image
    }
}
