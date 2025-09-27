import SwiftUI
import MapKit

struct HandoffView: View {
    let order: Order
    let run: Run?

    @State private var region: MKCoordinateRegion?

    private var regionBinding: Binding<MKCoordinateRegion>? {
        guard let region else { return nil }
        return Binding(
            get: { self.region ?? region },
            set: { self.region = $0 }
        )
    }

    private var statuses: [OrderStatus] {
        OrderStatusTimeline.statuses(for: order.status)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                mapSection
                statusSection
                if let meetPoint = order.meetPoint {
                    meetPointSection(meetPoint)
                }
                if let run {
                    dasherSection(run)
                }
            }
            .padding(24)
        }
        .navigationTitle("Handoff")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let point = order.meetPoint {
                region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude),
                    span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
                )
            }
        }
    }

    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Meet-up overview")
                .font(.headline)
            ZStack(alignment: .bottomLeading) {
                if let bindingRegion = regionBinding {
                    Map(coordinateRegion: bindingRegion, annotationItems: annotationItems) { point in
                        MapMarker(coordinate: point.coordinate, tint: Color.accentColor)
                    }
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                        .frame(height: 220)
                        .overlay { Text("Awaiting meet point…").foregroundStyle(.secondary) }
                }
                if let point = order.meetPoint {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(point.title)
                            .font(.headline)
                        Text(point.description)
                            .font(.footnote)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(12)
                }
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Order status")
                .font(.headline)
            ForEach(statuses, id: \.self) { status in
                TimelineRow(status: status, isCurrent: status == order.status)
            }
            if !order.pinCode.isEmpty {
                HStack {
                    Label("Delivery PIN", systemImage: "key.fill")
                    Spacer()
                    Text(order.pinCode)
                        .font(.title3.weight(.semibold))
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private func meetPointSection(_ meetPoint: MeetPoint) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Meet point details")
                .font(.headline)
            Text(meetPoint.title)
                .font(.subheadline.weight(.medium))
            Text(meetPoint.description)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func dasherSection(_ run: Run) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Dasher")
                .font(.headline)
            HStack(alignment: .center, spacing: 16) {
                    Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 52, height: 52)
                    .overlay {
                        Image(systemName: "bolt.fill")
                            .font(.title3)
                            .foregroundStyle(Color.accentColor)
                    }
                VStack(alignment: .leading, spacing: 4) {
                    Text(run.dasherId ?? "Assigning")
                        .font(.subheadline.weight(.semibold))
                    Text("Tap to chat via in-app messaging once connected.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            if let pickupTime = run.pickedUpAt {
                Label("Picked up at \(pickupTime.formatted(date: .omitted, time: .shortened))", systemImage: "bag.fill")
                    .font(.footnote)
            }
            Label("Estimated payout: \(String(format: "$%.2f", Double(run.estimatedPayoutCents) / 100.0))", systemImage: "dollarsign.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var annotationItems: [MeetPointAnnotation] {
        guard let point = order.meetPoint else { return [] }
        return [MeetPointAnnotation(coordinate: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude))]
    }
}

private struct TimelineRow: View {
    let status: OrderStatus
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isCurrent ? Color.accentColor : Color(.tertiarySystemFill))
                .frame(width: 14, height: 14)
                .overlay {
                    if isCurrent {
                        Circle().stroke(Color.white, lineWidth: 3)
                    }
                }
            Text(status.displayLabel)
                .font(isCurrent ? .subheadline.weight(.semibold) : .subheadline)
                .foregroundStyle(isCurrent ? .primary : .secondary)
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

private struct MeetPointAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

enum OrderStatusTimeline {
    static func statuses(for status: OrderStatus) -> [OrderStatus] {
        switch status {
        case .requested, .pooled, .readyToAssign, .claimed, .inProgress, .delivered, .paid, .closed:
            return [.requested, .pooled, .readyToAssign, .claimed, .inProgress, .delivered, .paid, .closed]
        case .expired:
            return [.requested, .expired]
        case .cancelledBuyer:
            return [.requested, .cancelledBuyer]
        case .cancelledDasher:
            return [.readyToAssign, .cancelledDasher]
        case .disputed:
            return [.delivered, .disputed]
        }
    }
}

private extension OrderStatus {
    var displayLabel: String {
        switch self {
        case .requested: return "Requested"
        case .pooled: return "Paired"
        case .readyToAssign: return "Searching for dasher"
        case .claimed: return "Dasher claimed"
        case .inProgress: return "En route"
        case .delivered: return "Delivered"
        case .paid: return "Payment processed"
        case .closed: return "Closed"
        case .expired: return "Expired"
        case .cancelledBuyer: return "Cancelled by you"
        case .cancelledDasher: return "Dasher cancelled"
        case .disputed: return "Dispute filed"
        }
    }
}
