import Foundation
import AuthenticationServices
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
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
                return "We couldn’t verify your credential. Please try again."
            }
        }
    }

    private func validateDomain(for email: String) throws -> School {
        guard let school = SchoolDirectory.school(forEmail: email) else {
            throw AuthError.unsupportedDomain
        }
        return school
    }

    func register(firstName: String,
                  lastName: String,
                  email: String,
                  password: String,
                  phoneNumber: String?,
                  school: School) async throws -> UserProfile {
        _ = try validateDomain(for: email)
        let authResult = try await manager.auth.createUser(withEmail: email, password: password)
        let profile = buildProfile(uid: authResult.user.uid,
                                   firstName: firstName,
                                   lastName: lastName,
                                   email: email,
                                   phoneNumber: phoneNumber,
                                   schoolId: school.id)
        try await saveProfile(profile)
        return profile
    }

    func signIn(withEmail email: String, password: String) async throws -> UserProfile {
        _ = try validateDomain(for: email)
        let authResult = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AuthDataResult, Error>) in
            manager.auth.signIn(withEmail: email, password: password) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown authentication error"]))
                }
            }
        }
        return try await fetchProfile(uid: authResult.user.uid)
    }

    func signInWithGoogle(presenting viewController: UIViewController) async throws -> UserProfile {
        let signInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
        guard let idToken = signInResult.user.idToken?.tokenString else {
            throw AuthError.invalidCredential
        }
        let email = signInResult.user.profile?.email ?? ""
        let school = try validateDomain(for: email)
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: signInResult.user.accessToken.tokenString)
        let authResult = try await manager.auth.signIn(with: credential)
        let profile = try await ensureProfile(for: authResult.user,
                                             firstName: signInResult.user.profile?.givenName,
                                             lastName: signInResult.user.profile?.familyName,
                                             schoolId: school.id)
        return profile
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential, currentNonce: String?) async throws -> UserProfile {
        guard let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.invalidCredential
        }
        let firebaseCredential = OAuthProvider.credential(withProviderID: "apple.com",
                                                          idToken: tokenString,
                                                          rawNonce: currentNonce)
        let authResult = try await manager.auth.signIn(with: firebaseCredential)
        let email = authResult.user.email ?? credential.email ?? ""
        let school = try validateDomain(for: email)
        let profile = try await ensureProfile(for: authResult.user,
                                             firstName: credential.fullName?.givenName,
                                             lastName: credential.fullName?.familyName,
                                             schoolId: school.id)
        return profile
    }

    func signOut() throws {
        try manager.auth.signOut()
    }

    func sendPasswordReset(to email: String) async throws {
        try await manager.auth.sendPasswordReset(withEmail: email)
    }

    func fetchProfile(uid: String) async throws -> UserProfile {
        let snapshot = try await manager.db.collection("users").document(uid).getDocument()
        return try snapshot.data(as: UserProfile.self)
    }

    func updatePushToken(_ token: String, for uid: String) async throws {
        try await manager.db.collection("users").document(uid).updateData(["pushToken": token])
    }

    func ensureStripeOnboarding(for uid: String) async throws -> Bool {
        let callable = manager.functions.httpsCallable("requestStripeOnboarding")
        let result = try await callable.call(["uid": uid])
        guard let data = result.data as? [String: Any],
              let completed = data["completed"] as? Bool else {
            return false
        }
        return completed
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
        try await manager.db.collection("users").document(uid).updateData([
            "schoolId": schoolId
        ])
        return try await fetchProfile(uid: uid)
    }

    private func ensureProfile(for user: FirebaseAuth.User,
                               firstName: String?,
                               lastName: String?,
                               schoolId: String?) async throws -> UserProfile {
        if let existing = try? await fetchProfile(uid: user.uid) {
            if existing.schoolId == nil, let schoolId {
                try await manager.db.collection("users").document(user.uid).updateData([
                    "schoolId": schoolId
                ])
                var updated = existing
                updated.schoolId = schoolId
                return updated
            }
            return existing
        }

        let resolvedSchoolId = schoolId ?? SchoolDirectory.school(forEmail: user.email ?? "")?.id
        let profile = buildProfile(uid: user.uid,
                                   firstName: firstName ?? "",
                                   lastName: lastName ?? "",
                                   email: user.email ?? "",
                                   phoneNumber: user.phoneNumber,
                                   schoolId: resolvedSchoolId)
        try await saveProfile(profile)
        return profile
    }

    private func buildProfile(uid: String,
                              firstName: String,
                              lastName: String,
                              email: String,
                              phoneNumber: String?,
                              schoolId: String?) -> UserProfile {
        UserProfile(
            id: uid,
            firstName: firstName.isEmpty ? "Lion" : firstName,
            lastName: lastName.isEmpty ? "Dash" : lastName,
            email: email,
            phoneNumber: phoneNumber,
            rolePreferences: [.buyer, .dasher],
            rating: 5.0,
            completedRuns: 0,
            stripeConnected: false,
            pushToken: nil,
            schoolId: schoolId,
            defaultPaymentMethodId: nil,
            paymentProviderPreferences: PaymentMethodType.defaultOrder,
            settings: .default
        )
    }

    private func saveProfile(_ profile: UserProfile) async throws {
        let document = manager.db.collection("users").document(profile.id)
        try document.setData(from: profile)
    }
}
