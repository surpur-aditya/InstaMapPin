import SwiftUI
import UIKit

struct SpotRowView: View {
    let spot: Spot

    var body: some View {
        HStack(spacing: 12) {
            MapThumbnail(latitude: spot.latitude, longitude: spot.longitude, size: 88)

            VStack(alignment: .leading, spacing: 5) {
                Text(spot.displayName)
                    .font(.headline)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !spot.categories.isEmpty {
                    categoryChips
                }

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(spot.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .contextMenu {
            Button {
                UIPasteboard.general.string = spot.address ?? coordinateString
            } label: {
                Label("Copy Address", systemImage: "doc.on.doc")
            }
            Button {
                UIPasteboard.general.string = coordinateString
            } label: {
                Label("Copy Coordinates", systemImage: "scope")
            }
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(spot.categories, id: \.self) { category in
                    Text(category)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var coordinateString: String {
        String(format: "%.6f, %.6f", spot.latitude, spot.longitude)
    }

    private var subtitle: String {
        if let address = spot.address {
            return address
        }
        if spot.needsAddressLookup {
            return "Finding address…"
        }
        return coordinateString
    }

    private var accessibilityLabel: String {
        var parts = [spot.displayName]
        if !spot.categories.isEmpty {
            parts.append(spot.categories.joined(separator: ", "))
        }
        if let address = spot.address {
            parts.append(address)
        }
        parts.append(spot.createdAt.formatted(date: .omitted, time: .shortened))
        return parts.joined(separator: ", ")
    }
}
