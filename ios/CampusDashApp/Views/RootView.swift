import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @State private var tab: Int = 0

    var body: some View {
        TabView(selection: $tab) {
            HomeView()
                .tabItem { Label("Order", systemImage: "bag.fill") }
                .tag(0)

            DasherAssignmentsView()
                .tabItem { Label("Dash", systemImage: "bolt.fill") }
                .tag(1)

            WalletView()
                .tabItem { Label("Wallet", systemImage: "wallet.pass.fill") }
                .tag(2)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(3)
        }
        .onAppear {
            if appState.activeDiningHall == nil {
                appState.activeDiningHall = nil
            }
        }
    }
}
