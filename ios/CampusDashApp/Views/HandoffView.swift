import SwiftUI

struct HandoffView: View {
    let order: Order
    let run: Run?

    var body: some View {
        VStack(spacing: 16) {
            Text("Order Status")
                .font(.title2)
            statusTimeline
            if let meetPoint = order.meetPoint {
                meetPointSection(meetPoint)
            }
            if let run {
                Text("Dasher: \(run.dasherId ?? "Unassigned")")
                    .font(.headline)
            }
            Spacer()
        }
        .padding()
        .navigationTitle("Handoff")
    }

    private var statusTimeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(OrderStatusTimeline.statuses(for: order.status), id: \.self) { status in
                HStack {
                    Image(systemName: status == order.status ? "largecircle.fill.circle" : "circle")
                    Text(status.rawValue.capitalized)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func meetPointSection(_ meetPoint: MeetPoint) -> some View {
        VStack(alignment: .leading) {
            Text(meetPoint.title)
                .font(.headline)
            Text(meetPoint.description)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
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
