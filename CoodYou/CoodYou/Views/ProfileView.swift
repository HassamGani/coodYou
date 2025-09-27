import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showingAdmin = false
    private let roleColumns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                profileHeader
                verificationCard
                roleSection
                walletOnboarding
                settingsSection
                if appState.currentUser?.rolePreferences.contains(.admin) == true {
                    adminSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 32)
            .padding(.bottom, 48)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAdmin) {
            AdminDashboardView()
        }
    }

    private var profileHeader: some View {
        Group {
            if let user = appState.currentUser {
                VStack(spacing: 16) {
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 96, height: 96)
                        .overlay {
                            Text(user.initials)
                                .font(.title.weight(.bold))
                                .foregroundStyle(.accentColor)
                        }
                    VStack(spacing: 4) {
                        Text("\(user.firstName) \(user.lastName)")
                            .font(.title2.weight(.semibold))
                        Text(user.email)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 16) {
                        StatPill(label: "Rating", value: String(format: "%.2f", user.rating))
                        StatPill(label: "Runs", value: "\(user.completedRuns)")
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: Color.black.opacity(0.06), radius: 20, y: 12)
            } else {
                VStack(spacing: 12) {
                    Text("Sign in to manage your profile")
                        .font(.headline)
                    Text("We’ll keep your stats, payments, and verification here once you onboard.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
        }
    }

    private var verificationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Verification")
                .font(.headline)
            if let user = appState.currentUser {
                VerificationRow(icon: "envelope.fill", title: ".edu email", status: user.email.hasSuffix(".edu") ? .verified : .pending)
                VerificationRow(icon: "phone.fill", title: "Phone", status: user.phoneNumber == nil ? .pending : .verified)
                VerificationRow(icon: "lock.shield", title: "Two-factor", status: .comingSoon)
            } else {
                Text("Sign in to view verification status.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var roleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Roles")
                .font(.headline)
            if let roles = appState.currentUser?.rolePreferences {
                LazyVGrid(columns: roleColumns, alignment: .leading, spacing: 8) {
                    ForEach(roles, id: \.self) { role in
                        Text(role.displayName)
                            .font(.footnote.weight(.semibold))
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            } else {
                Text("No roles selected yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var walletOnboarding: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Payouts")
                .font(.headline)
            if let user = appState.currentUser {
                if user.stripeConnected {
                    Label("Stripe Connect account active", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                } else {
                    Text("Set up Stripe to receive dasher payouts.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button {
                        Task { _ = try? await AuthService.shared.ensureStripeOnboarding(for: user.id) }
                    } label: {
                        Text("Finish Connect onboarding")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.headline)
            Button {
                try? AuthService.shared.signOut()
                appState.reset()
            } label: {
                Label("Sign out", systemImage: "arrow.right.square")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .tint(.red)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var adminSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Admin")
                .font(.headline)
            Text("Manage dining hall windows, pools, and disputes.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button {
                showingAdmin = true
            } label: {
                Label("Open admin console", systemImage: "gearshape.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct StatPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private enum VerificationStatus {
    case verified
    case pending
    case comingSoon

    var label: String {
        switch self {
        case .verified: return "Verified"
        case .pending: return "Pending"
        case .comingSoon: return "Coming soon"
        }
    }

    var color: Color {
        switch self {
        case .verified: return .green
        case .pending: return .orange
        case .comingSoon: return .gray
        }
    }
}

private struct VerificationRow: View {
    let icon: String
    let title: String
    let status: VerificationStatus

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .frame(width: 28, height: 28)
                .foregroundStyle(.accentColor)
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(status.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(status.color)
        }
    }
}

private extension UserRole {
    var displayName: String {
        switch self {
        case .buyer: return "Buyer"
        case .dasher: return "Dasher"
        case .admin: return "Admin"
        }
    }
}

private extension UserProfile {
    var initials: String {
        let first = firstName.first.map(String.init) ?? ""
        let last = lastName.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }
}
