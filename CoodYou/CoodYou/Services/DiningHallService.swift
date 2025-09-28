import Foundation
import FirebaseFirestore
import CoreLocation

@MainActor
final class DiningHallService: ObservableObject {
    static let shared = DiningHallService()

    @Published private(set) var halls: [DiningHall] = []

    private let db = FirebaseManager.shared.db
    private var hallsById: [String: DiningHall] = [:]
    private var hallsBySchool: [String: [DiningHall]] = [:]
    private var loadTask: Task<[DiningHall], Error>?

    private init() {}

    func ensureHallsLoaded() async throws {
        if !halls.isEmpty { return }
        try await refreshHalls()
    }

    func refreshHalls() async throws {
        if let loadTask {
            _ = try await loadTask.value
            return
        }

        try await SchoolService.shared.ensureSchoolsLoaded()
        let schoolList = SchoolService.shared.schools
        let schoolsById = Dictionary(uniqueKeysWithValues: schoolList.map { ($0.id, $0) })

        let task = Task<[DiningHall], Error> { [db, schoolList, schoolsById] in
            let primarySnapshot = try await db.collection("diningHalls").getDocuments()
            let documents: [QueryDocumentSnapshot]
            if primarySnapshot.documents.isEmpty {
                let legacy = try await db.collection("dining_halls")
                    .whereField("active", isEqualTo: true)
                    .getDocuments()
                documents = legacy.documents
            } else {
                documents = primarySnapshot.documents
            }

            return documents.compactMap { document in
                do {
                    var record = try document.data(as: DiningHallDocument.self)
                    record.id = document.documentID
                    return record.makeDiningHall(schoolsById: schoolsById, allSchools: schoolList)
                } catch {
                    print("[DiningHallService] Failed to decode dining hall \(document.documentID): \(error)")
                    return nil
                }
            }
        }

        loadTask = task

        do {
            let fetched = try await task.value
            var halls = fetched
            let existingIds = Set(halls.map { $0.id })
            let fallbacks = DiningHallStaticData.entries
                .filter { !existingIds.contains($0.id) }
                .map { $0.makeDiningHall() }
            halls.append(contentsOf: fallbacks)
            applyCache(with: halls)
        } catch {
            loadTask = nil
            throw error
        }

        loadTask = nil
    }

    func hall(withId id: String) -> DiningHall? {
        hallsById[id]
    }

    func halls(forSchoolId id: String) -> [DiningHall] {
        hallsBySchool[id] ?? []
    }

    func searchHalls(matching query: String) -> [DiningHall] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return halls }
        let tokens = trimmed.lowercased().split(separator: " ")
        return halls.filter { hall in
            let haystack = [hall.name, hall.campus, hall.address, hall.city, hall.state]
                .compactMap { $0?.lowercased() }
                .joined(separator: " ")
            return tokens.allSatisfy { haystack.contains($0) }
        }
    }

    private func applyCache(with halls: [DiningHall]) {
        let sorted = halls.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        self.halls = sorted
        self.hallsById = Dictionary(uniqueKeysWithValues: sorted.map { ($0.id, $0) })
        self.hallsBySchool = Dictionary(grouping: sorted, by: { $0.schoolId })
    }
}

private struct DiningHallDocument: Codable {
    var id: String?
    var name: String
    var schoolId: String?
    var campus: String?
    var latitude: Double?
    var longitude: Double?
    var active: Bool?
    var price_breakfast: Double?
    var price_lunch: Double?
    var price_dinner: Double?
    var geofenceRadius: Double?
    var address: String?
    var location: String?
    var menuIds: [String]?
    var iconName: String?
    var city: String?
    var state: String?
    var defaultOpenState: Bool?

    func makeDiningHall(schoolsById: [String: School], allSchools: [School]) -> DiningHall? {
        guard let id else { return nil }
        let resolvedSchoolId: String
        if let schoolId, let school = schoolsById[schoolId] {
            resolvedSchoolId = school.id
        } else if let campus,
                  let school = allSchools.first(where: { $0.displayName.caseInsensitiveCompare(campus) == .orderedSame || $0.name.caseInsensitiveCompare(campus) == .orderedSame }) {
            resolvedSchoolId = school.id
        } else if let school = allSchools.first(where: { $0.primaryDiningHallIds.contains(id) }) {
            resolvedSchoolId = school.id
        } else {
            resolvedSchoolId = allSchools.first?.id ?? "unknown"
        }

        let resolvedSchoolName = schoolsById[resolvedSchoolId]?.displayName ?? (campus ?? "")

        let lat = latitude ?? 0
        let lon = longitude ?? 0
        if abs(lat) < 0.0001 && abs(lon) < 0.0001 {
            return nil
        }
        let price = DiningHallPrice(
            breakfast: price_breakfast ?? DiningHallPrice.standard.breakfast,
            lunch: price_lunch ?? DiningHallPrice.standard.lunch,
            dinner: price_dinner ?? DiningHallPrice.standard.dinner
        )

        let resolvedAddress = address ?? location ?? ""

        return DiningHall(
            id: id,
            schoolId: resolvedSchoolId,
            name: name,
            campus: resolvedSchoolName,
            latitude: lat,
            longitude: lon,
            active: active ?? true,
            price: price,
            geofenceRadius: geofenceRadius ?? 75,
            address: resolvedAddress,
            menuIds: menuIds ?? [],
            iconName: iconName,
            city: city,
            state: state,
            defaultOpenState: defaultOpenState ?? true
        )
    }
}
