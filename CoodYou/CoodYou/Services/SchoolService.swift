import Foundation
import FirebaseFirestore

@MainActor
final class SchoolService: ObservableObject {
    static let shared = SchoolService()

    @Published private(set) var schools: [School] = []

    private let db = FirebaseManager.shared.db
    private var schoolsById: [String: School] = [:]
    private var domainsToSchool: [String: School] = [:]
    private var lastLoadTask: Task<[School], Error>?

    private init() {}

    func ensureSchoolsLoaded() async throws {
        if !schools.isEmpty { return }
        try await refreshSchools()
    }

    func refreshSchools() async throws {
        if let lastLoadTask {
            _ = try await lastLoadTask.value
            return
        }

        let task = Task<[School], Error> { [db] in
            let snapshot = try await db.collection("schools")
                .whereField("active", isEqualTo: true)
                .getDocuments()
            return snapshot.documents.compactMap { document in
                do {
                    let record = try document.data(as: SchoolDocument.self)
                    return record.makeSchool(id: document.documentID)
                } catch {
                    print("[SchoolService] Failed to decode school \(document.documentID): \(error)")
                    return nil
                }
            }
        }
        lastLoadTask = task

        do {
            let fetched = try await task.value
            applyCache(with: fetched)
        } catch {
            lastLoadTask = nil
            throw error
        }

        lastLoadTask = nil
    }

    func school(withId id: String) -> School? {
        schoolsById[id]
    }

    func school(forEmail email: String) -> School? {
        let lowered = email.lowercased()
        guard let domain = lowered.split(separator: "@").last else { return nil }
        return domainsToSchool[String(domain)]
    }

    private func applyCache(with schools: [School]) {
        let sorted = schools.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        self.schools = sorted
        self.schoolsById = Dictionary(uniqueKeysWithValues: sorted.map { ($0.id, $0) })
        self.domainsToSchool = sorted.reduce(into: [:]) { partialResult, school in
            for domain in school.allowedEmailDomains {
                partialResult[domain.lowercased()] = school
            }
        }
    }
}

private struct SchoolDocument: Codable {
    var name: String
    var displayName: String
    var allowedDomains: [String]
    var campusIconName: String?
    var city: String
    var state: String
    var country: String?
    var primaryDiningHallIds: [String]?
    var active: Bool?

    func makeSchool(id: String) -> School {
        School(
            id: id,
            name: name,
            displayName: displayName,
            allowedEmailDomains: allowedDomains,
            campusIconName: campusIconName ?? "building.columns",
            city: city,
            state: state,
            country: country ?? "USA",
            primaryDiningHallIds: primaryDiningHallIds ?? []
        )
    }
}
