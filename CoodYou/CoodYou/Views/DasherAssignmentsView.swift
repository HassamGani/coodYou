import SwiftUI

struct DasherAssignmentsView: View {
    @StateObject private var vm = DasherViewModel()
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationView {
            List(vm.assignments) { run in
                VStack(alignment: .leading) {
                    Text("Run: \(run.id)")
                    Text("Payout: \(run.estimatedPayoutCents) cents")
                }
            }
            .navigationTitle("Assignments")
        }
    }
}
