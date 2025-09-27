import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: Tab = .order

    private enum Tab: Int {
        case order, dash, wallet, profile

        var label: some View {
            switch self {
            case .order:
                return Label("Order", systemImage: "bag.fill")
            case .dash:
                return Label("Dash", systemImage: "bolt.car")
            case .wallet:
                return Label("Wallet", systemImage: "wallet.pass.fill")
            case .profile:
                return Label("Profile", systemImage: "person.crop.circle")
            }
        }
    }

    var body: some View {
        Group {
            switch appState.sessionPhase {
            case .loading:
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
            case .signedOut:
                NavigationStack {
                    LandingView()
                }
            case .needsSchoolSelection:
                NavigationStack {
                    SchoolSelectionView()
                }
            case .active:
                TabView(selection: $selectedTab) {
                    NavigationStack { HomeView() }
                        .tabItem { Tab.order.label }
                        .tag(Tab.order)

                    NavigationStack { DasherAssignmentsView() }
                        .tabItem { Tab.dash.label }
                        .tag(Tab.dash)

                    NavigationStack { WalletView() }
                        .tabItem { Tab.wallet.label }
                        .tag(Tab.wallet)

                    NavigationStack { ProfileView() }
                        .tabItem { Tab.profile.label }
                        .tag(Tab.profile)
                }
            }
        }
        .onChange(of: appState.activeRole) { _, newRole in
            if newRole == .dasher {
                selectedTab = .dash
            } else {
                selectedTab = .order
            }
        }
        .task {
            if appState.activeRole == .dasher {
                selectedTab = .dash
            }
        }
        .animation(.easeInOut, value: appState.sessionPhase)
    }
}
