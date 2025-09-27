import SwiftUI

struct DasherAssignmentsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = DasherViewModel()
    @State private var selectedRun: Run?
    @State private var deliveryPin: String = ""

    private var totalPotentialPayout: Double {
        viewModel.assignments.reduce(0) { $0 + Double($1.estimatedPayoutCents) / 100.0 }
    }

    private var activeRunsCount: Int {
        viewModel.assignments.filter { $0.status != .closed && $0.status != .cancelled }.count
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            VStack(alignment: .leading, spacing: 20) {
                header
                metrics
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.assignments) { run in
                            RunCard(
                                run: run,
                                hall: viewModel.hall(for: run),
                                action: primaryAction(for: run),
                                actionHandler: { action in
                                    handleRunAction(action, run: run)
                                }
                            )
                            .onTapGesture { selectedRun = run }
                        }
                        if viewModel.assignments.isEmpty {
                            emptyState
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .padding(.top, 16)
        }
        .navigationTitle("Dash")
        .toolbarTitleDisplayMode(.inline)
        .task {
            if let uid = appState.currentUser?.id {
                viewModel.bindAssignments(for: uid)
            }
        }
        .onChange(of: appState.currentUser?.id) { _, newValue in
            guard let newValue else { return }
            viewModel.bindAssignments(for: newValue)
        }
        .alert(item: Binding(
            get: { viewModel.errorMessage.map(ErrorMessage.init(value:)) },
            set: { viewModel.errorMessage = $0?.value }
        )) { message in
            Alert(title: Text("Error"), message: Text(message.value), dismissButton: .default(Text("OK")))
        }
        .sheet(item: $selectedRun) { run in
            RunDetailSheet(
                run: run,
                hall: viewModel.hall(for: run),
                deliveryPin: $deliveryPin,
                primaryAction: primaryAction(for: run),
                actionHandler: { action in
                    handleRunAction(action, run: run)
                }
            )
            .presentationDetents([.medium, .large])
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(viewModel.isOnline ? "You’re online" : "Go online", systemImage: viewModel.isOnline ? "bolt.fill" : "bolt.slash")
                    .font(.headline)
                    .foregroundStyle(viewModel.isOnline ? .primary : .secondary)
                Spacer()
                Toggle("", isOn: $viewModel.isOnline)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    .frame(width: 50)
            }
            Text("Stay inside the dining hall geofence to receive instant run offers. When you go offline we’ll pause push notifications.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 16)
    }

    private var metrics: some View {
        HStack(spacing: 12) {
            MetricPill(title: "Active runs", value: "\(activeRunsCount)")
            MetricPill(title: "Potential", value: String(format: "$%.2f", totalPotentialPayout))
            MetricPill(title: "Orders", value: "\(viewModel.assignments.flatMap { $0.orders }.count)")
        }
        .padding(.horizontal, 16)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.walk")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No runs right now")
                .font(.headline)
            Text("Stay online near a dining hall to be first in line when pairs are ready to deliver.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func primaryAction(for run: Run) -> RunAction? {
        switch run.status {
        case .readyToAssign:
            return .claim
        case .claimed:
            return .pickUp
        case .inProgress:
            return .deliver
        default:
            return nil
        }
    }

    private func handleRunAction(_ action: RunAction, run: Run) {
        Task {
            switch action {
            case .claim:
                await viewModel.claim(runId: run.id)
            case .pickUp:
                await viewModel.markPickedUp(runId: run.id)
            case .deliver:
                guard !deliveryPin.isEmpty else {
                    selectedRun = run
                    return
                }
                await viewModel.markDelivered(runId: run.id, pin: deliveryPin)
                deliveryPin = ""
            }
        }
    }
}

private struct MetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct RunCard: View {
    let run: Run
    let hall: DiningHall?
    let action: RunAction?
    let actionHandler: (RunAction) -> Void

    private var payout: String {
        String(format: "$%.2f", Double(run.estimatedPayoutCents) / 100.0)
    }

    private var ordersSubtitle: String {
        "\(run.orders.count) orders · PIN \(run.deliveryPin ?? "••••")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(hall?.name ?? "Dining hall")
                        .font(.headline)
                    Text(ordersSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(payout)
                        .font(.title3.weight(.semibold))
                    Text(run.status.displayLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: run.status.progressValue)
                .tint(.accentColor)

            if let action {
                Button {
                    actionHandler(action)
                } label: {
                    Text(action.ctaTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            } else {
                Text("Waiting for buyer confirmation or payout release.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 20, y: 12)
    }
}

private struct RunDetailSheet: View {
    let run: Run
    let hall: DiningHall?
    @Binding var deliveryPin: String
    let primaryAction: RunAction?
    let actionHandler: (RunAction) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                orderList
                timeline
                if let action = primaryAction {
                    actionSection(for: action)
                }
            }
            .padding(24)
        }
        .presentationDragIndicator(.visible)
        .onAppear {
            deliveryPin = run.deliveryPin ?? ""
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(hall?.name ?? "Dining hall run")
                .font(.title3.weight(.semibold))
            Text("Run #\(run.id.prefix(8)) · \(String(format: "$%.2f", Double(run.estimatedPayoutCents) / 100.0))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var orderList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Orders")
                .font(.headline)
            ForEach(run.orders) { order in
                VStack(alignment: .leading, spacing: 4) {
                    Text("Order #\(order.id.prefix(6))")
                        .font(.subheadline.weight(.medium))
                    Text(order.windowType.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status timeline")
                .font(.headline)
            ForEach(RunStatus.allCases, id: \.self) { status in
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: run.status == status ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(run.status == status ? .accentColor : .secondary)
                    Text(status.displayLabel)
                        .foregroundStyle(status == run.status ? .primary : .secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func actionSection(for action: RunAction) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.headline)
            if action == .deliver {
                TextField("Enter delivery PIN", text: $deliveryPin)
                    .textFieldStyle(.roundedBorder)
            }
            Button {
                actionHandler(action)
            } label: {
                Text(action.ctaTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }
}

private enum RunAction: Hashable {
    case claim
    case pickUp
    case deliver

    var ctaTitle: String {
        switch self {
        case .claim: return "Claim this run"
        case .pickUp: return "Mark as picked up"
        case .deliver: return "Complete delivery"
        }
    }
}
