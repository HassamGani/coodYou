import SwiftUI
import FirebaseFirestore

struct WalletView: View {
    @EnvironmentObject private var appState: AppState
    @State private var earnings: [PaymentRecord] = []
    @State private var totalPayout: Double = 0
    @State private var pendingPayout: Double = 0
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                summaryCard
                payoutBreakdown
                transactionsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Wallet")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadEarnings() }
        .refreshable { await loadEarnings() }
        .alert(item: Binding(
            get: { errorMessage.map(ErrorMessage.init(value:)) },
            set: { errorMessage = $0?.value }
        )) { message in
            Alert(title: Text("Error"), message: Text(message.value), dismissButton: .default(Text("OK")))
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available balance")
                .font(.headline)
            // Use server-maintained wallet balance when available
            Text(String(format: "$%.2f", Double(appState.currentUser?.walletBalanceCents ?? Int(totalPayout * 100)) / 100.0))
                .font(.system(size: 42, weight: .bold))
            HStack {
                Label(String(format: "$%.2f pending", pendingPayout), systemImage: "clock")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Transfer to bank") {}
                    .font(.footnote.weight(.semibold))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color.accentColor.opacity(0.1), in: Capsule())
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 24, y: 12)
    }

    private var payoutBreakdown: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly snapshot")
                .font(.headline)
            HStack(spacing: 16) {
                SnapshotTile(title: "Runs", value: "\(earnings.count)", subtitle: "Last 7 payouts")
                SnapshotTile(title: "Avg per run", value: averagePerRun, subtitle: "After fees")
                SnapshotTile(title: "Tips", value: "$0.00", subtitle: "Coming soon")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent payouts")
                    .font(.headline)
                Spacer()
                Button("Export") {}
                    .font(.footnote)
            }
            if earnings.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "wallet.pass")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No payouts yet")
                        .font(.headline)
                    Text("Start dashing to see your transfers and Stripe deposits here.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 12) {
                    ForEach(earnings) { record in
                        TransactionRow(record: record)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var averagePerRun: String {
        guard !earnings.isEmpty else { return "$0.00" }
        let avg = totalPayout / Double(earnings.count)
        return String(format: "$%.2f", avg)
    }

    private func loadEarnings() async {
        guard let uid = appState.currentUser?.id else { return }
        do {
            // If the current user is a dasher (canDash), show payouts. Otherwise, leave earnings empty.
            if appState.currentUser?.canDash == true {
                let snapshot = try await FirebaseManager.shared.db
                    .collection("payments")
                    .whereField("dasherId", isEqualTo: uid)
                    .order(by: "createdAt", descending: true)
                    .limit(to: 25)
                    .getDocuments()
                let records = try snapshot.documents.map { try $0.data(as: PaymentRecord.self) }
                await MainActor.run {
                    self.earnings = records
                    self.totalPayout = records.filter { $0.status == .captured }.reduce(0) { $0 + Double($1.payoutCents) / 100.0 }
                    self.pendingPayout = records.filter { $0.status == .pending }.reduce(0) { $0 + Double($1.payoutCents) / 100.0 }
                }
            } else {
                await MainActor.run {
                    self.earnings = []
                    self.totalPayout = 0
                    self.pendingPayout = 0
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}

private struct SnapshotTile: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct TransactionRow: View {
    let record: PaymentRecord

    private var payout: String {
        String(format: "$%.2f", Double(record.payoutCents) / 100.0)
    }

    private var statusColor: Color {
        switch record.status {
        case .captured: return .green
        case .pending: return .orange
        case .cancelled, .refunded: return .red
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Circle()
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "bag.fill")
                        .foregroundStyle(Color.accentColor)
                }
            VStack(alignment: .leading, spacing: 4) {
                Text("Run #\(record.runId.prefix(6))")
                    .font(.subheadline.weight(.semibold))
                Text("Buyers: \(record.buyerIds.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(payout)
                    .font(.headline)
                Text(record.status.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
