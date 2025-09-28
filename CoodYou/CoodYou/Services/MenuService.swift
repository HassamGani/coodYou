import Foundation
import FirebaseFirestore

actor MenuService {
    static let shared = MenuService()

    private let session: URLSession
    private let jsonDecoder: JSONDecoder
    private let apiBase = URL(string: "https://apiv4.dineoncampus.com")!
    private let db = FirebaseManager.shared.db

    private init() {
        session = URLSession(configuration: .default)
        jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .iso8601
    }

    func menu(for hall: DiningHall, on date: Date = Date()) async throws -> DiningHallMenu {
        let dateString = Self.dateFormatter.string(from: date)
        if let stored = try await fetchStoredMenu(hallId: hall.id, date: dateString) {
            return stored
        }

        guard let metadata = DiningHallStaticData.menuMetadata(for: hall.id) else {
            return comingSoonMenu(for: hall, statusMessage: "Menu coming soon")
        }

        let headers = headers(for: metadata)
        async let todaysMenuTask = fetchTodaysMenu(siteId: metadata.siteId, date: dateString, headers: headers)
        async let locationsPublicTask = fetchLocationsPublic(siteId: metadata.siteId, headers: headers)

        let menuResponse = try await todaysMenuTask
        let locationsResponse = try await locationsPublicTask

        guard let locationEntry = menuResponse.locations.first(where: { $0.id == metadata.locationId }) else {
            return comingSoonMenu(for: hall, statusMessage: "Menu not published")
        }

        let locationPublic = locationsResponse.location(withId: metadata.locationId)
        let statusMessage = locationPublic?.status?.message
        let isOpen = locationPublic?.status?.isOpen ?? hall.defaultOpenState
        let scheduleMap = locationPublic?.publishedPeriodTimes ?? [:]
        let fallback = Self.fallbackSchedule(for: date)
        let schedule = scheduleMap.isEmpty ? fallback : scheduleMap

        let periodNames = locationEntry.periods.compactMap { $0.name }
        let now = Self.currentTime(in: Self.timeZone, for: date)
        let activePeriod = Self.chooseCurrentPeriod(periodNames: periodNames, schedule: schedule, reference: now)
        let periodRangeText = activePeriod.flatMap { Self.formatRange(start: $0.start, end: $0.end, on: date) }

        let menuPeriod = activePeriod.flatMap { periodInfo in
            locationEntry.periods.first { $0.name == periodInfo.name }
        } ?? locationEntry.periods.first

        let mealPeriodModel: DiningHallMenu.MealPeriod?
        if let period = menuPeriod, let name = period.name {
            let times = activePeriod ?? Self.chooseCurrentPeriod(periodNames: [name], schedule: schedule, reference: now)
            let formattedRange = times.flatMap { Self.formatRange(start: $0.start, end: $0.end, on: date) }
            let startDate = times.flatMap { Self.timeFormatter.date(from: $0.start) }
            let endDate = times.flatMap { Self.timeFormatter.date(from: $0.end) }
            mealPeriodModel = DiningHallMenu.MealPeriod(
                name: name,
                start: startDate,
                end: endDate,
                formattedRange: formattedRange
            )
        } else {
            mealPeriodModel = nil
        }

        let stations = menuPeriod?.stations.compactMap { station -> DiningHallMenu.Station? in
            guard let stationName = station.name else { return nil }
            let items = station.items.compactMap { item -> DiningHallMenu.MenuItem? in
                guard let itemName = item.name, !itemName.isEmpty else { return nil }
                return DiningHallMenu.MenuItem(id: item.id ?? UUID().uuidString, name: itemName)
            }
            return DiningHallMenu.Station(id: station.id ?? UUID().uuidString, name: stationName, items: items)
        } ?? []

        let status = DiningHallStatus(
            isOpen: isOpen,
            statusMessage: statusMessage,
            currentPeriodName: mealPeriodModel?.name ?? activePeriod?.name,
            periodRangeText: mealPeriodModel?.formattedRange ?? periodRangeText
        )

        return DiningHallMenu(
            hallId: hall.id,
            status: status,
            currentPeriod: mealPeriodModel,
            stations: stations,
            isComingSoon: false
        )
    }

    private func comingSoonMenu(for hall: DiningHall, statusMessage: String?) -> DiningHallMenu {
        let status = DiningHallStatus(
            isOpen: hall.defaultOpenState,
            statusMessage: statusMessage,
            currentPeriodName: nil,
            periodRangeText: nil
        )
        return DiningHallMenu(
            hallId: hall.id,
            status: status,
            currentPeriod: nil,
            stations: [],
            isComingSoon: true
        )
    }

    private func fetchStoredMenu(hallId: String, date: String) async throws -> DiningHallMenu? {
        let snapshot = try await db.collection("menus")
            .whereField("diningHallId", isEqualTo: hallId)
            .whereField("date", isEqualTo: date)
            .limit(to: 1)
            .getDocuments()

        guard let document = snapshot.documents.first else { return nil }
        let record = try document.data(as: MenuDocument.self)
        return record.makeMenu()
    }
}

private extension MenuService {
    struct TodaysMenuResponse: Decodable {
        let locations: [MenuLocation]
    }

    struct MenuLocation: Decodable {
        let id: String
        let name: String?
        let periods: [MenuPeriod]
    }

    struct MenuPeriod: Decodable {
        let id: String?
        let name: String?
        let stations: [MenuStation]
    }

    struct MenuStation: Decodable {
        let id: String?
        let name: String?
        let items: [MenuItem]
    }

    struct MenuItem: Decodable {
        let id: String?
        let name: String?
    }

    struct MenuDocument: Codable {
        struct DocumentMealPeriod: Codable {
            struct DocumentStation: Codable {
                struct DocumentItem: Codable {
                    var id: String?
                    var name: String
                }

                var id: String?
                var name: String?
                var items: [DocumentItem]?
            }

            var name: String
            var start: String?
            var end: String?
            var formattedRange: String?
            var stations: [DocumentStation]?
        }

        var diningHallId: String
        var date: String
        var isOpen: Bool?
        var statusMessage: String?
        var currentPeriodName: String?
        var periodRangeText: String?
        var mealPeriods: [DocumentMealPeriod]

        func makeMenu() -> DiningHallMenu {
            let status = DiningHallStatus(
                isOpen: isOpen ?? true,
                statusMessage: statusMessage,
                currentPeriodName: currentPeriodName,
                periodRangeText: periodRangeText
            )

            guard let period = mealPeriods.first else {
                return DiningHallMenu(
                    hallId: diningHallId,
                    status: status,
                    currentPeriod: nil,
                    stations: [],
                    isComingSoon: false
                )
            }

            let startDate = period.start.flatMap { MenuService.timeFormatter.date(from: $0) }
            let endDate = period.end.flatMap { MenuService.timeFormatter.date(from: $0) }
            let menuPeriod = DiningHallMenu.MealPeriod(name: period.name,
                                                       start: startDate,
                                                       end: endDate,
                                                       formattedRange: period.formattedRange)

            let stations = (period.stations ?? []).map { station -> DiningHallMenu.Station in
                let items = (station.items ?? []).map { item in
                    DiningHallMenu.MenuItem(id: item.id ?? UUID().uuidString, name: item.name)
                }
                return DiningHallMenu.Station(id: station.id ?? UUID().uuidString,
                                               name: station.name ?? "Station",
                                               items: items)
            }

            return DiningHallMenu(
                hallId: diningHallId,
                status: status,
                currentPeriod: menuPeriod,
                stations: stations,
                isComingSoon: false
            )
        }
    }

    struct LocationsPublicResponse: Decodable {
        let buildings: [Building]

        struct Building: Decodable {
            let locations: [Location]
        }

        struct Location: Decodable {
            let id: String
            let status: Status?
            let periodHours: [String: PeriodTime]?
            let mealPeriods: [String: PeriodTime]?
            let schedule: [String: PeriodTime]?
            let hours: [String: PeriodTime]?

            struct Status: Decodable {
                let message: String?
                let isOpen: Bool?

                enum CodingKeys: String, CodingKey {
                    case message
                    case isOpen = "is_open"
                }
            }
            var publishedPeriodTimes: [String: (String, String)] {
                let candidates = [periodHours, mealPeriods, schedule, hours]
                for candidate in candidates {
                    if let candidate {
                        let mapped = candidate.compactMapValues { period -> (String, String)? in
                            guard let start = period.start, let end = period.end else { return nil }
                            return (start, end)
                        }
                        if !mapped.isEmpty { return mapped }
                    }
                }
                return [:]
            }
        }

        struct PeriodTime: Decodable {
            let start: String?
            let end: String?
        }

        func location(withId id: String) -> Location? {
            for building in buildings {
                if let match = building.locations.first(where: { $0.id == id }) {
                    return match
                }
            }
            return nil
        }
    }

    static let timeZone = TimeZone(identifier: "America/New_York")!

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = timeZone
        return formatter
    }()

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = timeZone
        return formatter
    }()

    static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        formatter.timeZone = timeZone
        return formatter
    }()

    static func fallbackSchedule(for date: Date) -> [String: (String, String)] {
        let weekday = Calendar.current.component(.weekday, from: date)
        let isWeekend = weekday == 1 || weekday == 7
        if isWeekend {
            return [
                "Breakfast": ("09:00", "11:29"),
                "Lunch": ("11:30", "16:29"),
                "Dinner": ("16:30", "20:30")
            ]
        } else {
            return [
                "Breakfast": ("07:00", "10:59"),
                "Lunch": ("11:00", "16:59"),
                "Dinner": ("17:00", "21:00")
            ]
        }
    }

    static func currentTime(in timeZone: TimeZone, for date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var components = calendar.dateComponents(in: timeZone, from: Date())
        let requestedDay = calendar.dateComponents(in: timeZone, from: date)
        components.year = requestedDay.year
        components.month = requestedDay.month
        components.day = requestedDay.day
        return calendar.date(from: components) ?? date
    }

    static func chooseCurrentPeriod(periodNames: [String], schedule: [String: (String, String)], reference: Date) -> (name: String, start: String, end: String)? {
        for name in periodNames {
            guard let window = schedule[name] else { continue }
            if time(reference, isBetween: window.0, and: window.1) {
                return (name, window.0, window.1)
            }
        }
        return nil
    }

    static func time(_ reference: Date, isBetween start: String, and end: String) -> Bool {
        guard let startDate = timeFormatter.date(from: start), let endDate = timeFormatter.date(from: end) else {
            return false
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let startComponents = calendar.dateComponents([.hour, .minute], from: startDate)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endDate)
        let referenceComponents = calendar.dateComponents(in: timeZone, from: reference)
        let referenceDate = calendar.date(from: referenceComponents) ?? reference
        let startOfDay = calendar.startOfDay(for: referenceDate)

        guard let intervalStart = calendar.date(bySettingHour: startComponents.hour ?? 0, minute: startComponents.minute ?? 0, second: 0, of: startOfDay) else {
            return false
        }
        var intervalEnd = calendar.date(bySettingHour: endComponents.hour ?? 0, minute: endComponents.minute ?? 0, second: 0, of: startOfDay) ?? intervalStart

        if intervalEnd < intervalStart {
            intervalEnd = calendar.date(byAdding: .day, value: 1, to: intervalEnd) ?? intervalEnd
        }

        return referenceDate >= intervalStart && referenceDate <= intervalEnd
    }

    static func formatRange(start: String?, end: String?, on date: Date) -> String? {
        guard let start, let end,
              let startDate = timeFormatter.date(from: start),
              let endDate = timeFormatter.date(from: end) else {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let startComponents = calendar.dateComponents([.hour, .minute], from: startDate)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endDate)

        guard
            let base = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: date),
            let actualStart = calendar.date(bySettingHour: startComponents.hour ?? 0, minute: startComponents.minute ?? 0, second: 0, of: base),
            let actualEnd = calendar.date(bySettingHour: endComponents.hour ?? 0, minute: endComponents.minute ?? 0, second: 0, of: base)
        else {
            return nil
        }

        return "\(displayFormatter.string(from: actualStart)) – \(displayFormatter.string(from: actualEnd))"
    }

    func fetchTodaysMenu(siteId: String, date: String, headers: [String: String]) async throws -> TodaysMenuResponse {
        var components = URLComponents(url: apiBase.appendingPathComponent("sites/todays_menu"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "siteId", value: siteId),
            URLQueryItem(name: "date", value: date)
        ]
        let request = buildRequest(url: components.url!, headers: headers)
        let (data, _) = try await session.data(for: request)
        return try jsonDecoder.decode(TodaysMenuResponse.self, from: data)
    }

    func fetchLocationsPublic(siteId: String, headers: [String: String]) async throws -> LocationsPublicResponse {
        var components = URLComponents(url: apiBase.appendingPathComponent("sites/\(siteId)/locations-public"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "for_map", value: "true")]
        let request = buildRequest(url: components.url!, headers: headers)
        let (data, _) = try await session.data(for: request)
        return try jsonDecoder.decode(LocationsPublicResponse.self, from: data)
    }

    func buildRequest(url: URL, headers: [String: String]) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        return request
    }

    func headers(for metadata: DiningHallStaticData.MenuMetadata) -> [String: String] {
        [
            "Content-Type": "application/json",
            "Accept": "application/json, text/plain, */*",
            "User-Agent": metadata.userAgent,
            "Origin": "https://dineoncampus.com",
            "Referer": metadata.referer
        ]
    }
}
