import Foundation

struct DiningHallMenu: Equatable {
    struct MealPeriod: Equatable {
        let name: String
        let start: Date?
        let end: Date?
        let formattedRange: String?
    }

    struct Station: Identifiable, Equatable {
        let id: String
        let name: String
        let items: [MenuItem]
    }

    struct MenuItem: Identifiable, Equatable {
        let id: String
        let name: String
    }

    let hallId: String
    let status: DiningHallStatus
    let currentPeriod: MealPeriod?
    let stations: [Station]
    let isComingSoon: Bool
}

struct DiningHallStatus: Equatable {
    let isOpen: Bool
    let statusMessage: String?
    let currentPeriodName: String?
    let periodRangeText: String?
}

struct CartItem: Identifiable, Equatable {
    let id: UUID
    let hallId: String
    let name: String

    init(id: UUID = UUID(), hallId: String, name: String) {
        self.id = id
        self.hallId = hallId
        self.name = name
    }
}
