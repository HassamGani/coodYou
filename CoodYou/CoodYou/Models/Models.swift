import Foundation
import CoreLocation

struct UserProfile: Identifiable, Codable {
    var id: String
    var firstName: String
    var lastName: String
    var email: String
    var phoneNumber: String?
    var rolePreferences: [UserRole]
    var rating: Double
    var completedRuns: Int
    var stripeConnected: Bool
    var pushToken: String?
    var schoolId: String?
    var defaultPaymentMethodId: String?
    var paymentProviderPreferences: [PaymentMethodType] = PaymentMethodType.defaultOrder
    var settings: UserSettings = .default
}

enum UserRole: String, Codable, CaseIterable {
    case buyer
    case dasher
    case admin
}

enum ServiceWindowType: String, Codable, CaseIterable {
    case breakfast
    case lunch
    case dinner
    case current

    static func determineWindow(from date: Date = Date(), config: ServiceWindowConfig) -> ServiceWindowType {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        if hour >= config.dinner.startHour || hour < config.breakfast.startHour {
            return .dinner
        }
        if hour >= config.lunch.startHour && hour < config.lunch.endHour {
            return .lunch
        }
        return .breakfast
    }
}

struct ServiceWindow: Codable, Identifiable {
    let id: String
    let hallId: String
    let type: ServiceWindowType
    let start: Date
    let end: Date
}

struct ServiceWindowConfig: Codable {
    struct WindowRange: Codable {
        var startHour: Int
        var endHour: Int
    }

    var breakfast: WindowRange
    var lunch: WindowRange
    var dinner: WindowRange

    static var `default`: ServiceWindowConfig {
        ServiceWindowConfig(
            breakfast: .init(startHour: 7, endHour: 12),
            lunch: .init(startHour: 12, endHour: 17),
            dinner: .init(startHour: 17, endHour: 21)
        )
    }
}

struct DiningHall: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var campus: String
    var latitude: Double
    var longitude: Double
    var active: Bool
    var price: DiningHallPrice
    var geofenceRadius: Double
    var address: String
    var dineOnCampusSiteId: String?
    var dineOnCampusLocationId: String?
    var affiliation: DiningHallAffiliation
    var defaultOpenState: Bool

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

enum DiningHallAffiliation: String, Codable, Hashable {
    case columbia
    case barnard
}

struct DiningHallPrice: Codable, Hashable {
    var breakfast: Double
    var lunch: Double
    var dinner: Double
}

struct Order: Identifiable, Codable {
    var id: String
    var userId: String
    var hallId: String
    var status: OrderStatus
    var windowType: ServiceWindowType
    var priceCents: Int
    var createdAt: Date
    var pairGroupId: String?
    var meetPoint: MeetPoint?
    var pinCode: String
    var isSoloFallback: Bool
}

enum OrderStatus: String, Codable {
    case requested
    case pooled
    case readyToAssign
    case claimed
    case inProgress
    case delivered
    case paid
    case closed
    case expired
    case cancelledBuyer
    case cancelledDasher
    case disputed
}

struct MeetPoint: Codable, Hashable {
    var title: String
    var description: String
    var latitude: Double
    var longitude: Double
}

struct Run: Identifiable, Codable {
    var id: String
    var dasherId: String?
    var hallId: String
    var pairGroupId: String
    var status: RunStatus
    var orders: [Order] = []
    var pickedUpAt: Date?
    var deliveredAt: Date?
    var estimatedPayoutCents: Int
    var deliveryPin: String?
}

enum RunStatus: String, Codable, CaseIterable {
    case readyToAssign
    case claimed
    case inProgress
    case delivered
    case paid
    case closed
    case cancelled
    
    var displayLabel: String {
        switch self {
        case .readyToAssign: return "Available"
        case .claimed: return "Claimed"
        case .inProgress: return "In progress"
        case .delivered: return "Delivered"
        case .paid: return "Paid"
        case .closed: return "Closed"
        case .cancelled: return "Cancelled"
        }
    }
    
    var progressValue: Double {
        switch self {
        case .readyToAssign: return 0.1
        case .claimed: return 0.35
        case .inProgress: return 0.7
        case .delivered: return 0.9
        case .paid, .closed: return 1
        case .cancelled: return 0
        }
    }

    var sortIndex: Int {
        switch self {
        case .readyToAssign: return 0
        case .claimed: return 1
        case .inProgress: return 2
        case .delivered: return 3
        case .paid: return 4
        case .closed: return 5
        case .cancelled: return 6
        }
    }
}

struct PaymentRecord: Identifiable, Codable {
    var id: String
    var runId: String
    var dasherId: String
    var buyerIds: [String]
    var amountCents: Int
    var feeCents: Int
    var payoutCents: Int
    var status: PaymentStatus
    var createdAt: Date
}

enum PaymentStatus: String, Codable {
    case pending
    case captured
    case refunded
    case cancelled
}

struct LivePoolSnapshot: Codable {
    var hallId: String
    var windowType: ServiceWindowType
    var queueSize: Int
    var averageWaitSeconds: TimeInterval
}

struct NotificationPayload: Codable {
    var title: String
    var body: String
    var hallId: String
    var windowType: ServiceWindowType
    var runId: String?
}

extension Order {
    var isTerminal: Bool {
        switch status {
        case .paid, .closed, .cancelledBuyer, .cancelledDasher, .expired, .disputed:
            return true
        default:
            return false
        }
    }
}

struct UserSettings: Codable, Hashable {
    var pushNotificationsEnabled: Bool
    var locationSharingEnabled: Bool
    var autoAcceptDashRuns: Bool
    var applePayDoubleConfirmation: Bool

    static let `default` = UserSettings(
        pushNotificationsEnabled: true,
        locationSharingEnabled: true,
        autoAcceptDashRuns: false,
        applePayDoubleConfirmation: true
    )
}

struct PaymentMethod: Identifiable, Codable, Hashable {
    var id: String
    var userId: String
    var type: PaymentMethodType
    var displayName: String
    var details: String?
    var last4: String?
    var isDefault: Bool
    var createdAt: Date

    var badgeTitle: String {
        switch type {
        case .stripeCard, .card:
            return "Card"
        case .applePay:
            return "Apple Pay"
        case .paypal:
            return "PayPal"
        case .cashApp:
            return "Cash App"
        }
    }
}

enum PaymentMethodType: String, Codable, CaseIterable, Hashable, Identifiable {
    case stripeCard
    case card
    case applePay
    case paypal
    case cashApp

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .stripeCard: return "Stripe-linked card"
        case .card: return "Saved card"
        case .applePay: return "Apple Pay"
        case .paypal: return "PayPal"
        case .cashApp: return "Cash App"
        }
    }

    static var defaultOrder: [PaymentMethodType] {
        [.applePay, .stripeCard, .card, .paypal, .cashApp]
    }
}

struct School: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var displayName: String
    var allowedEmailDomains: [String]
    var campusIconName: String
    var city: String
    var state: String
    var country: String
    var primaryDiningHallIds: [String]

    func supports(email: String) -> Bool {
        let lowered = email.lowercased()
        guard let domain = lowered.split(separator: "@").last else { return false }
        return allowedEmailDomains.contains { $0.caseInsensitiveCompare(domain) == .orderedSame }
    }
}

extension OrderStatus {
    var progressValue: Double {
        switch self {
        case .requested: return 0.1
        case .pooled: return 0.25
        case .readyToAssign: return 0.4
        case .claimed: return 0.6
        case .inProgress: return 0.8
        case .delivered, .paid, .closed: return 1
        case .expired, .cancelledBuyer, .cancelledDasher, .disputed: return 0.5
        }
    }

    var buyerFacingLabel: String {
        switch self {
        case .requested: return "Waiting for a match"
        case .pooled: return "Pairing you up"
        case .readyToAssign: return "Searching for dashers"
        case .claimed: return "Dasher on the way"
        case .inProgress: return "Meal being delivered"
        case .delivered: return "Delivered"
        case .paid: return "Payment complete"
        case .closed: return "Closed"
        case .expired: return "Expired"
        case .cancelledBuyer: return "Cancelled"
        case .cancelledDasher: return "Reassigning"
        case .disputed: return "Dispute in review"
        }
    }
}
