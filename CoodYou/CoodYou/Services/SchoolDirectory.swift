import Foundation

enum SchoolDirectory {
    static let columbia = School(
        id: "columbia",
        name: "Columbia University",
        displayName: "Columbia University & Barnard College",
        allowedEmailDomains: ["columbia.edu", "barnard.edu"],
        campusIconName: "building.columns",
        city: "New York",
        state: "NY",
        country: "USA",
        primaryDiningHallIds: DiningHallDirectory.all.map { $0.id }
    )

    static let all: [School] = [columbia]

    static func school(withId id: String) -> School? {
        all.first { $0.id == id }
    }

    static func school(forEmail email: String) -> School? {
        all.first { $0.supports(email: email) }
    }
}
