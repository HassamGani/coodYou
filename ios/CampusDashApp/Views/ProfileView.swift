import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showingAdmin = false

    var body: some View {
        NavigationView {
            Form {
                if let user = appState.currentUser {
                    Section("Identity") {
                        Text("Name: \(user.firstName) \(user.lastName)")
                        Text("Email: \(user.email)")
                        Text("Rating: \(String(format: "%.2f", user.rating))")
                    }

                    Section("Roles") {
                        ForEach(user.rolePreferences, id: \.self) { role in
                            Text(role.rawValue.capitalized)
                        }
                    }

                    Section("Stripe") {
                        if user.stripeConnected {
                            Label("Connected", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                        } else {
                            Button("Complete Onboarding") {
                                Task {
                                    _ = try? await AuthService.shared.ensureStripeOnboarding(for: user.id)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        try? AuthService.shared.signOut()
                        appState.reset()
                    }
                }

                if appState.currentUser?.rolePreferences.contains(.admin) == true {
                    Section {
                        Button("Open Admin Console") { showingAdmin = true }
                    }
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showingAdmin) {
                AdminDashboardView()
            }
        }
    }
}
