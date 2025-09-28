import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
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
    private var userDocListener: ListenerRegistration?

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
        userDocListener?.remove()
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
        userDocListener?.remove()
        userDocListener = nil
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
            // Prefer server-provided eligibleSchoolIds when deciding selection.
            if let eligible = profile.eligibleSchoolIds, eligible.count > 0 {
                if eligible.count == 1 {
                    selectedSchool = await SchoolService.shared.school(withId: eligible[0])
                    sessionPhase = selectedSchool == nil ? .needsSchoolSelection : .active
                } else {
                    // Multiple eligible schools: user must choose which campus to operate in.
                    selectedSchool = nil
                    sessionPhase = .needsSchoolSelection
                }
            } else if let schoolId = profile.schoolId {
                selectedSchool = await SchoolService.shared.school(withId: schoolId)
                sessionPhase = selectedSchool == nil ? .needsSchoolSelection : .active
            } else {
                selectedSchool = nil
                sessionPhase = .needsSchoolSelection
            }

            // Attach a Firestore listener to the user's document so server-side updates
            // (auth-create function writing eligibleSchoolIds/schoolId) update the session automatically.
            userDocListener?.remove()
            userDocListener = FirebaseManager.shared.db.collection("users").document(user.uid).addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                Task { @MainActor in
                    if let snapshot = snapshot, snapshot.exists {
                        if let updated: UserProfile = try? snapshot.data(as: UserProfile.self) {
                            self.currentUser = updated
                            // Re-evaluate selectedSchool based on server-populated fields
                            if let eligible = updated.eligibleSchoolIds, eligible.count > 0 {
                                if eligible.count == 1 {
                                    self.selectedSchool = await SchoolService.shared.school(withId: eligible[0])
                                    self.sessionPhase = self.selectedSchool == nil ? .needsSchoolSelection : .active
                                } else {
                                    self.selectedSchool = nil
                                    self.sessionPhase = .needsSchoolSelection
                                }
                            } else if let schoolId = updated.schoolId {
                                self.selectedSchool = await SchoolService.shared.school(withId: schoolId)
                                self.sessionPhase = self.selectedSchool == nil ? .needsSchoolSelection : .active
                            }
                        }
                    }
                }
            }

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
