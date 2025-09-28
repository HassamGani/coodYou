import Foundation
import AuthenticationServices
import FirebaseAuth
import FirebaseFirestore
// GoogleSignIn is optional at compile-time. When the package isn't installed via SPM,
// use conditional import to avoid a build failure ("No such module 'GoogleSignIn'").
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
import UIKit

final class AuthService {
    static let shared = AuthService()
    private let manager = FirebaseManager.shared

    private init() {}

    enum AuthError: LocalizedError {
        case unsupportedDomain
        case missingSchoolSelection
        case invalidCredential

        var errorDescription: String? {
            switch self {
            case .unsupportedDomain:
                return "Use your @columbia.edu or @barnard.edu email to continue."
            case .missingSchoolSelection:
                return "Select your campus to finish onboarding."
            case .invalidCredential:
                return "We couldn't verify your credential. Please try again."
            }
        }
    }

    private func validateDomain(for email: String) async throws -> School {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        try await SchoolService.shared.ensureSchoolsLoaded()
        guard let school = await SchoolService.shared.school(forEmail: normalizedEmail) else {
            throw AuthError.unsupportedDomain
        }
        return school
    }

    func register(firstName: String,
                  lastName: String,
                  email: String,
                  password: String,
                  phoneNumber: String?,
                  selectedSchool: School?) async throws -> UserProfile {
        // Allow anyone to register. Only assign a schoolId and canDash when the email domain matches a participating school's allowed domains.
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPhone = phoneNumber?.trimmingCharacters(in: .whitespacesAndNewlines)

        try await SchoolService.shared.ensureSchoolsLoaded()

        // Create the Firebase auth user first
        let authResult = try await manager.auth.createUser(withEmail: normalizedEmail, password: password)

    // Build a minimal profile to store client-managed fields. Protected fields (canDash, schoolId, etc.)
    // are authoritative server-side (cloud function). We include non-protected fields and return a local
    // representation; server will augment the doc when the auth trigger runs.
    let profile = buildProfile(uid: authResult.user.uid,
                   firstName: firstName,
                   lastName: lastName,
                   email: normalizedEmail,
                   phoneNumber: normalizedPhone,
                   schoolId: nil)

    try await saveClientProfile(profile)
    return profile
    }

    func signIn(withEmail email: String, password: String) async throws -> UserProfile {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        // Allow any email to sign in; don't enforce domain here. We'll resolve school membership when building/ensuring profiles.
        let authResult = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AuthDataResult, Error>) in
            manager.auth.signIn(withEmail: normalizedEmail, password: password) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown authentication error"]))
                }
            }
        }
        // Fetch or create profile; ensureProfile will assign schoolId/canDash if the user's email matches an allowed domain.
        return try await ensureProfile(for: authResult.user, firstName: nil, lastName: nil, schoolId: nil)
    }

    #if canImport(GoogleSignIn)
    func signInWithGoogle(presenting viewController: UIViewController) async throws -> UserProfile {
        let signInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
        guard let idToken = signInResult.user.idToken?.tokenString else {
            throw AuthError.invalidCredential
        }
        let email = signInResult.user.profile?.email ?? ""
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        // Allow any Google account to sign in. Resolve a school by email if possible and pass it to ensureProfile.
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: signInResult.user.accessToken.tokenString)
        let authResult = try await manager.auth.signIn(with: credential)
        // Try to resolve a school for the Google account's email; pass nil if none.
        let resolvedSchoolId = await SchoolService.shared.school(forEmail: normalizedEmail)?.id
        let profile = try await ensureProfile(for: authResult.user,
                                             firstName: signInResult.user.profile?.givenName,
                                             lastName: signInResult.user.profile?.familyName,
                                             schoolId: resolvedSchoolId)
        return profile
    }
    #else
    // Stub implementation that throws when GoogleSignIn is not available at compile time.
    func signInWithGoogle(presenting viewController: UIViewController) async throws -> UserProfile {
        throw AuthError.invalidCredential
    }
    #endif

    func signInWithApple(credential: ASAuthorizationAppleIDCredential, currentNonce: String?) async throws -> UserProfile {
        guard let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.invalidCredential
        }
        guard let nonce = currentNonce else {
            throw AuthError.invalidCredential
        }
        let firebaseCredential = OAuthProvider.appleCredential(withIDToken: tokenString,
                                                               rawNonce: nonce,
                                                               fullName: credential.fullName)
        let authResult = try await manager.auth.signIn(with: firebaseCredential)
        let email = authResult.user.email ?? credential.email ?? ""
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedSchoolId = await SchoolService.shared.school(forEmail: normalizedEmail)?.id
        let profile = try await ensureProfile(for: authResult.user,
                                             firstName: credential.fullName?.givenName,
                                             lastName: credential.fullName?.familyName,
                                             schoolId: resolvedSchoolId)
        return profile
    }

    func signOut() throws {
        try manager.auth.signOut()
    }

    func sendPasswordReset(to email: String) async throws {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        try await manager.auth.sendPasswordReset(withEmail: normalizedEmail)
    }

    func fetchProfile(uid: String) async throws -> UserProfile {
        let snapshot = try await manager.db.collection("users").document(uid).getDocument()
        return try snapshot.data(as: UserProfile.self)
    }

    func updatePushToken(_ token: String, for uid: String) async throws {
        try await manager.db.collection("users").document(uid).updateData(["pushToken": token])
    }

    func ensureStripeOnboarding(for uid: String) async throws -> Bool {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            let callable = manager.functions.httpsCallable("requestStripeOnboarding")
            callable.call(["uid": uid]) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let data = result?.data as? [String: Any],
                      let completed = data["completed"] as? Bool else {
                    continuation.resume(returning: false)
                    return
                }
                continuation.resume(returning: completed)
            }
        }
    }

    func updateSettings(_ settings: UserSettings, for uid: String) async throws {
        try await manager.db.collection("users").document(uid).updateData([
            "settings": [
                "pushNotificationsEnabled": settings.pushNotificationsEnabled,
                "locationSharingEnabled": settings.locationSharingEnabled,
                "autoAcceptDashRuns": settings.autoAcceptDashRuns,
                "applePayDoubleConfirmation": settings.applePayDoubleConfirmation
            ]
        ])
    }

    func updateSchool(for uid: String, schoolId: String) async throws -> UserProfile {
        try await SchoolService.shared.ensureSchoolsLoaded()
        guard await SchoolService.shared.school(withId: schoolId) != nil else {
            throw AuthError.missingSchoolSelection
        }
        // Request server to set the authoritative schoolId after verifying eligibility.
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let callable = manager.functions.httpsCallable("requestSetSchool")
            callable.call(["uid": uid, "schoolId": schoolId]) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
        let profile = try await fetchProfile(uid: uid)
        return profile
    }

    private func ensureProfile(for user: FirebaseAuth.User,
                               firstName: String?,
                               lastName: String?,
                               schoolId: String?) async throws -> UserProfile {
        if let existing = try? await fetchProfile(uid: user.uid) {
            if existing.schoolId == nil, let schoolId {
                // Ask server to set the authoritative schoolId if eligible.
                let _ = try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    let callable = manager.functions.httpsCallable("requestSetSchool")
                    callable.call(["uid": user.uid, "schoolId": schoolId]) { result, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                            return
                        }
                        continuation.resume(returning: ())
                    }
                }
                // Fetch the profile again to get server-populated fields.
                return try await fetchProfile(uid: user.uid)
            }
            return existing
        }

        try? await SchoolService.shared.ensureSchoolsLoaded()
        var resolvedSchoolId = schoolId
        if resolvedSchoolId == nil {
            // await must be used in a standalone expression rather than to the right of '??' in some Swift language modes
            resolvedSchoolId = await SchoolService.shared.school(forEmail: user.email ?? "")?.id
        }
    let canDash = resolvedSchoolId != nil
    let profile = buildProfile(uid: user.uid,
                   firstName: firstName ?? "",
                   lastName: lastName ?? "",
                   email: user.email ?? "",
                   phoneNumber: user.phoneNumber,
                   schoolId: resolvedSchoolId,
                   canDash: canDash)
        // Save only client-manageable fields; server function will set canDash/schoolId authoritatively.
        try await saveClientProfile(profile)
        return profile
    }

    private func buildProfile(uid: String,
                              firstName: String,
                              lastName: String,
                              email: String,
                              phoneNumber: String?,
                              schoolId: String?,
                              canDash: Bool = false) -> UserProfile {
        var roles: [UserRole] = [.buyer]
        if canDash { roles.append(.dasher) }
        return UserProfile(
            id: uid,
            firstName: firstName.isEmpty ? "Lion" : firstName,
            lastName: lastName.isEmpty ? "Dash" : lastName,
            email: email,
            phoneNumber: phoneNumber,
            rolePreferences: roles,
            rating: 5.0,
            completedRuns: 0,
            stripeConnected: false,
            pushToken: nil,
            schoolId: schoolId,
            canDash: canDash,
            defaultPaymentMethodId: nil,
            paymentProviderPreferences: PaymentMethodType.defaultOrder,
            settings: .default,
            createdAt: Date()
        )
    }

    /// Save only fields that clients are allowed to write. Protected fields (canDash, rolePreferences, rating,
    /// completedRuns, stripeConnected, schoolId) are omitted so Firestore rules do not reject the write.
    private func saveClientProfile(_ profile: UserProfile) async throws {
        let document = manager.db.collection("users").document(profile.id)
        let payload: [String: Any] = [
            "id": profile.id,
            "firstName": profile.firstName,
            "lastName": profile.lastName,
            "email": profile.email,
            "phoneNumber": profile.phoneNumber as Any,
            "pushToken": profile.pushToken as Any,
            "defaultPaymentMethodId": profile.defaultPaymentMethodId as Any,
            "paymentProviderPreferences": profile.paymentProviderPreferences,
            "settings": [
                "pushNotificationsEnabled": profile.settings.pushNotificationsEnabled,
                "locationSharingEnabled": profile.settings.locationSharingEnabled,
                "autoAcceptDashRuns": profile.settings.autoAcceptDashRuns,
                "applePayDoubleConfirmation": profile.settings.applePayDoubleConfirmation
            ],
            "createdAt": profile.createdAt
        ]
        try await document.setData(payload, merge: true)
    }
}
