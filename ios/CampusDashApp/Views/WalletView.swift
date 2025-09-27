import SwiftUI

struct WalletView: View {
    @EnvironmentObject private var appState: AppState
    @State private var earnings: [PaymentRecord] = []
    @State private var totalPayout: Double = 0
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Total Payout")) {
                    Text("$\(totalPayout, specifier: "%.2f")")
                        .font(.largeTitle)
                }

                Section(header: Text("Recent Payouts")) {
                    ForEach(earnings) { record in
                        VStack(alignment: .leading) {
                            Text("Run #\(record.runId.prefix(6))")
                            Text("$\(Double(record.payoutCents) / 100.0, specifier: "%.2f")")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Buyers: \(record.buyerIds.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Wallet")
            .task { await loadEarnings() }
            .alert(item: Binding(
                get: { errorMessage.map(ErrorMessage.init(value:)) },
                set: { errorMessage = $0?.value }
            )) { message in
                Alert(title: Text("Error"), message: Text(message.value), dismissButton: .default(Text("OK")))
            }
        }
    }

    private func loadEarnings() async {
        guard let uid = appState.currentUser?.id else { return }
        do {
            let snapshot = try await FirebaseManager.shared.db
                .collection("payments")
                .whereField("dasherId", isEqualTo: uid)
                .order(by: "createdAt", descending: true)
                .limit(to: 25)
                .getDocuments()
            let records = try snapshot.documents.map { try $0.data(as: PaymentRecord.self) }
            earnings = records
            totalPayout = records.reduce(0) { $0 + Double($1.payoutCents) / 100.0 }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
