import Foundation
import FirebaseAuth
import FirebaseFirestore

final class AuthService {
    static let shared = AuthService()
    private let manager = FirebaseManager.shared

    private init() {}

    func signIn(withEmail email: String, password: String) async throws -> UserProfile {
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

    func signOut() throws {
        try manager.auth.signOut()
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
}
