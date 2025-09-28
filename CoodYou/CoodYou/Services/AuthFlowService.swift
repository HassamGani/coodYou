import Foundation
import SwiftUI

protocol AuthFlowService: Sendable {
    func requestCode(for email: String) async throws
    func verifyCode(email: String, code: String) async throws -> AuthFlowServiceResult
    func createAccount(name: String, email: String, password: String?) async throws -> AuthFlowServiceResult
    func forgotPassword(email: String) async throws
}

struct AuthFlowServiceResult: Sendable {
    let isNewUser: Bool
    let requiresLinking: Bool
}

enum AuthFlowError: LocalizedError, Sendable {
    case invalidEmail
    case invalidCode
    case expiredCode
    case accountExists
    case networkOffline
    case oauthCancelled
    case serverError

    var errorDescription: String? {
        switch self {
        case .invalidEmail: return NSLocalizedString("auth.error.invalidEmail", comment: "Invalid email")
        case .invalidCode: return NSLocalizedString("auth.error.invalidCode", comment: "Incorrect code")
        case .expiredCode: return NSLocalizedString("auth.error.expiredCode", comment: "Expired code")
        case .accountExists: return NSLocalizedString("auth.error.accountExists", comment: "Account exists")
        case .networkOffline: return NSLocalizedString("auth.error.offline", comment: "Offline")
        case .oauthCancelled: return NSLocalizedString("auth.error.oauthCancelled", comment: "Cancelled")
        case .serverError: return NSLocalizedString("auth.error.server", comment: "Server error")
        }
    }
}

actor MockAuthFlowService: AuthFlowService {
    private var codes: [String: String] = [:]
    var defaultResult = AuthFlowServiceResult(isNewUser: false, requiresLinking: false)

    func requestCode(for email: String) async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
        guard email.contains("@") else { throw AuthFlowError.invalidEmail }
        codes[email.lowercased()] = "123456"
    }

    func verifyCode(email: String, code: String) async throws -> AuthFlowServiceResult {
        try await Task.sleep(nanoseconds: 250_000_000)
        let sanitized = email.lowercased()
        guard let expected = codes[sanitized] else { throw AuthFlowError.expiredCode }
        guard expected == code else { throw AuthFlowError.invalidCode }
        return defaultResult
    }

    func createAccount(name: String, email: String, password: String?) async throws -> AuthFlowServiceResult {
        try await Task.sleep(nanoseconds: 350_000_000)
        guard !name.isEmpty else { throw AuthFlowError.serverError }
        guard email.contains("@") else { throw AuthFlowError.invalidEmail }
        return AuthFlowServiceResult(isNewUser: true, requiresLinking: false)
    }

    func forgotPassword(email: String) async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
        guard email.contains("@") else { throw AuthFlowError.invalidEmail }
    }

}
