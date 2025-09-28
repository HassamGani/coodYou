import Foundation
import AuthenticationServices
import FirebaseAuth
import FirebaseFirestore
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
        case googleSignInUnavailable

        var errorDescription: String? {
            switch self {
            case .unsupportedDomain:
                return "Use your @columbia.edu or @barnard.edu email to continue."
            case .missingSchoolSelection:
                return "Select your campus to finish onboarding."
            case .invalidCredential:
                return "We couldn’t verify your credential. Please try again."
            case .googleSignInUnavailable:
                return "Google Sign-In is not available in this build."
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
                  school: School) async throws -> UserProfile {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPhone = phoneNumber?.trimmingCharacters(in: .whitespacesAndNewlines)
        try await SchoolService.shared.ensureSchoolsLoaded()
        guard let resolvedSchool = await SchoolService.shared.school(withId: school.id) else {
            throw AuthError.missingSchoolSelection
        }
        guard resolvedSchool.supports(email: normalizedEmail) else {
            throw AuthError.unsupportedDomain
        }
        let authResult = try await manager.auth.createUser(withEmail: normalizedEmail, password: password)
        let profile = buildProfile(uid: authResult.user.uid,
                                   firstName: firstName,
                                   lastName: lastName,
                                   email: normalizedEmail,
                                   phoneNumber: normalizedPhone,
                                   schoolId: resolvedSchool.id)
        try await saveProfile(profile)
        return profile
    }

    func signIn(withEmail email: String, password: String) async throws -> UserProfile {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try await validateDomain(for: normalizedEmail)
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
        return try await fetchProfile(uid: authResult.user.uid)
    }

    func signInWithGoogle(presenting viewController: UIViewController) async throws -> UserProfile {
        #if canImport(GoogleSignIn)
        let signInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
        guard let idToken = signInResult.user.idToken?.tokenString else {
            throw AuthError.invalidCredential
        }
        let email = signInResult.user.profile?.email ?? ""
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let school = try await validateDomain(for: normalizedEmail)
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: signInResult.user.accessToken.tokenString)
        let authResult = try await manager.auth.signIn(with: credential)
        let profile = try await ensureProfile(for: authResult.user,
                                             firstName: signInResult.user.profile?.givenName,
                                             lastName: signInResult.user.profile?.familyName,
                                             schoolId: school.id)
        return profile
        #else
        throw AuthError.googleSignInUnavailable
        #endif
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential, currentNonce: String?) async throws -> UserProfile {
        guard let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.invalidCredential
        }
        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: tokenString,
            rawNonce: currentNonce,
            fullName: credential.fullName
        )
        let authResult = try await manager.auth.signIn(with: firebaseCredential)
        let email = authResult.user.email ?? credential.email ?? ""
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let school = try await validateDomain(for: normalizedEmail)
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
        try await SchoolService.shared.ensureSchoolsLoaded()
        guard let school = await SchoolService.shared.school(withId: schoolId) else {
            throw AuthError.missingSchoolSelection
        }
        try await manager.db.collection("users").document(uid).updateData([
            "schoolId": schoolId
        ])
        var profile = try await fetchProfile(uid: uid)
        profile.schoolId = school.id
        return profile
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

        try? await SchoolService.shared.ensureSchoolsLoaded()
        let resolvedSchoolId = schoolId ?? await SchoolService.shared.school(forEmail: user.email ?? "")?.id
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
            settings: .default,
            createdAt: Date()
        )
    }

    private func saveProfile(_ profile: UserProfile) async throws {
        let document = manager.db.collection("users").document(profile.id)
        try document.setData(from: profile)
    }
}
