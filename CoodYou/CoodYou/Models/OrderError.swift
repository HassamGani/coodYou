import Foundation

enum OrderError: LocalizedError {
    case noInternetConnection
    case emptyCart
    case invalidPaymentMethod
    case serverError(String)
    case noDashersAvailable
    case hallClosed
    
    var errorDescription: String? {
        switch self {
        case .noInternetConnection:
            return "No internet connection. Please check your network and try again."
        case .emptyCart:
            return "Your cart is empty. Add items before placing an order."
        case .invalidPaymentMethod:
            return "Please select a valid payment method."
        case .serverError(let message):
            return "Server error: \(message)"
        case .noDashersAvailable:
            return "No dashers are currently available. Try again later."
        case .hallClosed:
            return "This dining hall is currently closed."
        }
    }
}