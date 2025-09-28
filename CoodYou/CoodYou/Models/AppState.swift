import Foundation
import Combine
import FirebaseAuth

final class AppState: ObservableObject {
    enum SessionPhase {
        case loading
        case signedOut
        case needsSchoolSelection
        case active
    }

    @Published var currentUser: UserProfile?
    @Published var activeRole: UserRole = .buyer
    @Published var activeDiningHall: DiningHall?
    @Published var activeWindow: ServiceWindowType = .current
    @Published var activeRun: Run?
    @Published var pendingOrders: [Order] = []
    @Published var dasherAssignments: [Run] = []
    @Published var selectedSchool: School?
    @Published var paymentMethods: [PaymentMethod] = []
    @Published var sessionPhase: SessionPhase = .loading

    private var authHandle: AuthStateDidChangeListenerHandle?
    private var paymentTask: Task<Void, Never>?

    init() {
        authHandle = FirebaseManager.shared.auth.addStateDidChangeListener { [weak self] _, user in
            Task { await self?.handleAuthStateChange(user: user) }
        }
    }

    deinit {
        if let authHandle {
            FirebaseManager.shared.auth.removeStateDidChangeListener(authHandle)
        }
        paymentTask?.cancel()
    }

    func reset() {
        currentUser = nil
        activeRole = .buyer
        activeRun = nil
        pendingOrders = []
        dasherAssignments = []
        selectedSchool = nil
        paymentMethods = []
        sessionPhase = .signedOut
        paymentTask?.cancel()
        paymentTask = nil
    }

    @MainActor
    func refreshSession() async {
        await handleAuthStateChange(user: FirebaseManager.shared.auth.currentUser)
    }

    @MainActor
    private func handleAuthStateChange(user: FirebaseAuth.User?) async {
        paymentTask?.cancel()
        paymentTask = nil
        paymentMethods = []
        guard let user else {
            reset()
            return
        }

        sessionPhase = .loading
        do {
            let profile = try await AuthService.shared.fetchProfile(uid: user.uid)
            currentUser = profile
            try? await SchoolService.shared.ensureSchoolsLoaded()
            if let schoolId = profile.schoolId {
                selectedSchool = await SchoolService.shared.school(withId: schoolId)
            } else {
                selectedSchool = nil
            }
            sessionPhase = selectedSchool == nil ? .needsSchoolSelection : .active
            attachPaymentStream(for: user.uid)
        } catch {
            currentUser = nil
            selectedSchool = nil
            paymentMethods = []
            sessionPhase = .signedOut
        }
    }

    private func attachPaymentStream(for uid: String) {
        paymentTask?.cancel()
        paymentTask = Task { [weak self] in
            do {
                for try await methods in PaymentService.shared.observePaymentMethods(for: uid) {
                    await MainActor.run {
                        self?.paymentMethods = methods
                    }
                }
            } catch {
                await MainActor.run {
                    self?.paymentMethods = []
                }
            }
        }
    }
}
