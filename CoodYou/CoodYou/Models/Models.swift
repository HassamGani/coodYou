import Foundation
import CoreLocation

struct UserProfile: Identifiable, Codable {
    var id: String
    var firstName: String
    var lastName: String
    var email: String
    var phoneNumber: String?
    var rolePreferences: [UserRole] = [.buyer]
    var rating: Double = 5.0
    var completedRuns: Int = 0
    var stripeConnected: Bool = false
    var pushToken: String?
    var schoolId: String?
    // Wallet balance in cents (buyers) maintained by server/cloud functions
    var walletBalanceCents: Int = 0
    // Populated by server-side auth trigger when applicable. Clients may read this to present
    // multi-school eligibility for a user (e.g. cross-affiliated students/staff).
    var eligibleSchoolIds: [String]?
    var canDash: Bool = false
    var defaultPaymentMethodId: String?
    var paymentProviderPreferences: [PaymentMethodType] = PaymentMethodType.defaultOrder
    var settings: UserSettings = .default
    var createdAt: Date = Date()
}

extension UserProfile {
    private enum CodingKeys: String, CodingKey {
        case id
        case firstName
        case lastName
        case email
        case phoneNumber
        case rolePreferences
        case rating
        case completedRuns
        case stripeConnected
        case pushToken
        case schoolId
        case walletBalanceCents
        case eligibleSchoolIds
        case canDash
        case defaultPaymentMethodId
        case paymentProviderPreferences
        case settings
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        firstName = try container.decodeIfPresent(String.self, forKey: .firstName) ?? "Lion"
        lastName = try container.decodeIfPresent(String.self, forKey: .lastName) ?? "Dash"
        email = try container.decode(String.self, forKey: .email)
        phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber)
        if let roles = try container.decodeIfPresent([UserRole].self, forKey: .rolePreferences) {
            rolePreferences = roles
        }
        rating = try container.decodeIfPresent(Double.self, forKey: .rating) ?? 5.0
        completedRuns = try container.decodeIfPresent(Int.self, forKey: .completedRuns) ?? 0
        stripeConnected = try container.decodeIfPresent(Bool.self, forKey: .stripeConnected) ?? false
        pushToken = try container.decodeIfPresent(String.self, forKey: .pushToken)
        schoolId = try container.decodeIfPresent(String.self, forKey: .schoolId)
        walletBalanceCents = try container.decodeIfPresent(Int.self, forKey: .walletBalanceCents) ?? 0
        eligibleSchoolIds = try container.decodeIfPresent([String].self, forKey: .eligibleSchoolIds)
        canDash = try container.decodeIfPresent(Bool.self, forKey: .canDash) ?? false
        defaultPaymentMethodId = try container.decodeIfPresent(String.self, forKey: .defaultPaymentMethodId)
        if let paymentPrefs = try container.decodeIfPresent([PaymentMethodType].self, forKey: .paymentProviderPreferences) {
            paymentProviderPreferences = paymentPrefs
        }
        settings = try container.decodeIfPresent(UserSettings.self, forKey: .settings) ?? .default
        if let timestamp = try container.decodeIfPresent(Date.self, forKey: .createdAt) {
            createdAt = timestamp
        } else {
            createdAt = Date()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(firstName, forKey: .firstName)
        try container.encode(lastName, forKey: .lastName)
        try container.encode(email, forKey: .email)
        try container.encodeIfPresent(phoneNumber, forKey: .phoneNumber)
        try container.encode(rolePreferences, forKey: .rolePreferences)
        try container.encode(rating, forKey: .rating)
        try container.encode(completedRuns, forKey: .completedRuns)
        try container.encode(stripeConnected, forKey: .stripeConnected)
        try container.encodeIfPresent(pushToken, forKey: .pushToken)
        try container.encodeIfPresent(schoolId, forKey: .schoolId)
        try container.encode(walletBalanceCents, forKey: .walletBalanceCents)
        try container.encodeIfPresent(eligibleSchoolIds, forKey: .eligibleSchoolIds)
        try container.encode(canDash, forKey: .canDash)
        try container.encodeIfPresent(defaultPaymentMethodId, forKey: .defaultPaymentMethodId)
        try container.encode(paymentProviderPreferences, forKey: .paymentProviderPreferences)
        try container.encode(settings, forKey: .settings)
        try container.encode(createdAt, forKey: .createdAt)
    }
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
    var schoolId: String
    var name: String
    var campus: String
    var latitude: Double
    var longitude: Double
    var active: Bool
    var price: DiningHallPrice
    var geofenceRadius: Double
    var address: String
    var menuIds: [String]
    var iconName: String?
    var city: String?
    var state: String?
    var defaultOpenState: Bool

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct DiningHallPrice: Codable, Hashable {
    var breakfast: Double
    var lunch: Double
    var dinner: Double
}

extension DiningHallPrice {
    /// Default on-campus buffet pricing used when Firestore documents omit explicit amounts.
    static let standard = DiningHallPrice(breakfast: 13.0, lunch: 17.5, dinner: 19.5)
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
    var lineItems: [OrderLineItem]?
    var specialInstructions: String?
    var deliveryRequestId: String?
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

struct OrderLineItem: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var quantity: Int

    init(id: String = UUID().uuidString, name: String, quantity: Int = 1) {
        self.id = id
        self.name = name
        self.quantity = quantity
    }
}

enum DeliveryRequestStatus: String, Codable {
    case pending
    case notifyingDashers
    case awaitingAcceptance
    case accepted
    case matched
    case cancelled
    case expired
}

struct DeliveryRequest: Identifiable, Codable, Hashable {
    var id: String
    var orderId: String
    var buyerId: String
    var hallId: String
    var windowType: ServiceWindowType
    var status: DeliveryRequestStatus
    var requestedAt: Date
    var expiresAt: Date?
    var items: [OrderLineItem]
    var instructions: String?
    var meetPoint: MeetPoint?
    var assignedDasherId: String?
    var candidateDasherIds: [String]?

    var isActionable: Bool {
        switch status {
        case .pending, .notifyingDashers, .awaitingAcceptance:
            return true
        case .accepted, .matched, .cancelled, .expired:
            return false
        }
    }
}

struct DasherAvailability: Identifiable, Codable {
    var id: String
    var isOnline: Bool
    var updatedAt: Date
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
    var iconName: String
    var city: String
    var state: String
    var country: String
    var diningHallIds: [String]
    var primaryDiningHallIds: [String]
    var active: Bool

    var campusIconName: String { iconName }

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
