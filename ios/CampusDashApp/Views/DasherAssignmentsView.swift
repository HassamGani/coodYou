import SwiftUI

struct DasherAssignmentsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = DasherViewModel()

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.assignments) { run in
                    NavigationLink(destination: RunDetailView(run: run, viewModel: viewModel)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Run #\(run.id.prefix(6))")
                                .font(.headline)
                            HStack {
                                Text("Orders: \(run.orders.count)")
                                Spacer()
                                Text("$\(Double(run.estimatedPayoutCents) / 100.0, specifier: "%.2f")")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Dash Assignments")
            .overlay {
                if viewModel.assignments.isEmpty {
                    if #available(iOS 17.0, *) {
                        ContentUnavailableView("No assignments", systemImage: "bolt.slash")
                    } else {
                        VStack {
                            Image(systemName: "bolt.slash")
                                .font(.largeTitle)
                                .padding(.bottom, 4)
                            Text("No assignments")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onAppear {
                guard let uid = appState.currentUser?.id else { return }
                viewModel.bindAssignments(for: uid)
            }
        }
    }
}

struct RunDetailView: View {
    let run: Run
    @ObservedObject var viewModel: DasherViewModel
    @State private var pin: String = ""

    var body: some View {
        Form {
            Section("Orders") {
                ForEach(run.orders) { order in
                    VStack(alignment: .leading) {
                        Text("Order #\(order.id.prefix(6))")
                        Text(order.windowType.rawValue.capitalized)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let deliveryPin = run.deliveryPin {
                Section("Pair PIN") {
                    Text(deliveryPin)
                        .font(.title)
                        .bold()
                }
            }

            Section("Actions") {
                Button("Claim") {
                    Task { await viewModel.claim(runId: run.id) }
                }
                Button("Mark Picked Up") {
                    Task { await viewModel.markPickedUp(runId: run.id) }
                }
                VStack(alignment: .leading) {
                    TextField("Delivery PINs (comma separated)", text: $pin)
                    Button("Mark Delivered") {
                        Task { await viewModel.markDelivered(runId: run.id, pin: pin) }
                    }
                    .disabled(pin.isEmpty)
                }
            }
        }
        .navigationTitle("Run Details")
    }
}
