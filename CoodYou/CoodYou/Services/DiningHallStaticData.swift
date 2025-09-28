import Foundation

enum DiningHallStaticData {
    struct Entry {
        let id: String
        let schoolId: String
        let name: String
        let latitude: Double
        let longitude: Double
        let address: String
        let city: String?
        let state: String?
        let geofenceRadius: Double
        let defaultOpenState: Bool
        let iconName: String?
        let menuMetadata: MenuMetadata?

        func makeDiningHall() -> DiningHall {
            let campusName = schoolId.replacingOccurrences(of: "_", with: " ").capitalized
            return DiningHall(
                id: id,
                schoolId: schoolId,
                name: name,
                campus: campusName,
                latitude: latitude,
                longitude: longitude,
                active: true,
                price: .standard,
                geofenceRadius: geofenceRadius,
                address: address,
                menuIds: [],
                iconName: iconName,
                city: city,
                state: state,
                defaultOpenState: defaultOpenState
            )
        }
    }

    struct MenuMetadata {
        let siteId: String
        let locationId: String
        let referer: String
        let userAgent: String
    }

    private static let entriesBacking: [Entry] = [
        // Columbia dining halls
        Entry(id: "john_jay_dining_hall", schoolId: "columbia", name: "John Jay Dining Hall", latitude: 40.8065, longitude: -73.9632, address: "519 W 114th St, New York, NY 10027", city: "New York", state: "NY", geofenceRadius: 80, defaultOpenState: true, iconName: nil, menuMetadata: nil),
        Entry(id: "jjs_place", schoolId: "columbia", name: "JJ's Place", latitude: 40.8065, longitude: -73.9632, address: "519 W 114th St (Lower Level), New York, NY 10027", city: "New York", state: "NY", geofenceRadius: 70, defaultOpenState: true, iconName: nil, menuMetadata: nil),
        Entry(id: "ferris_booth_commons", schoolId: "columbia", name: "Ferris Booth Commons", latitude: 40.8074, longitude: -73.9637, address: "2920 Broadway, New York, NY 10027", city: "New York", state: "NY", geofenceRadius: 80, defaultOpenState: true, iconName: nil, menuMetadata: nil),
        Entry(id: "faculty_house", schoolId: "columbia", name: "Faculty House", latitude: 40.8090, longitude: -73.9615, address: "64 Morningside Dr, New York, NY 10027", city: "New York", state: "NY", geofenceRadius: 80, defaultOpenState: true, iconName: nil, menuMetadata: nil),
        Entry(id: "chef_mikes_sub_shop", schoolId: "columbia", name: "Chef Mike's Sub Shop", latitude: 40.8086, longitude: -73.9630, address: "2920 Broadway (Lerner Hall), New York, NY 10027", city: "New York", state: "NY", geofenceRadius: 60, defaultOpenState: true, iconName: nil, menuMetadata: nil),
        Entry(id: "chef_dons_pizza_pi", schoolId: "columbia", name: "Chef Don's Pizza Pi", latitude: 40.8086, longitude: -73.9631, address: "2920 Broadway (Lerner Hall), New York, NY 10027", city: "New York", state: "NY", geofenceRadius: 60, defaultOpenState: true, iconName: nil, menuMetadata: nil),
        Entry(id: "blue_java", schoolId: "columbia", name: "Blue Java", latitude: 40.8087, longitude: -73.9630, address: "2920 Broadway, New York, NY 10027", city: "New York", state: "NY", geofenceRadius: 60, defaultOpenState: true, iconName: nil, menuMetadata: nil),
        Entry(id: "grace_dodge_dining_hall", schoolId: "columbia", name: "Grace Dodge Dining Hall", latitude: 40.8101, longitude: -73.9633, address: "509 W 121st St, New York, NY 10027", city: "New York", state: "NY", geofenceRadius: 70, defaultOpenState: true, iconName: nil, menuMetadata: nil),
        Entry(id: "johnnys_food_truck", schoolId: "columbia", name: "Johnny's Food Truck", latitude: 40.8056, longitude: -73.9650, address: "Broadway & W 114th St, New York, NY 10027", city: "New York", state: "NY", geofenceRadius: 60, defaultOpenState: true, iconName: nil, menuMetadata: nil),
        Entry(id: "robert_f_smith_dining_hall", schoolId: "columbia", name: "Robert F. Smith Dining Hall", latitude: 40.8168, longitude: -73.9570, address: "1220 Amsterdam Ave, New York, NY 10027", city: "New York", state: "NY", geofenceRadius: 80, defaultOpenState: true, iconName: nil, menuMetadata: nil),
        Entry(id: "the_fac_shack", schoolId: "columbia", name: "The Fac Shack", latitude: 40.8092, longitude: -73.9611, address: "64 Morningside Dr, New York, NY 10027", city: "New York", state: "NY", geofenceRadius: 60, defaultOpenState: true, iconName: nil, menuMetadata: nil),

        // Barnard dining halls with menu metadata derived from scripts
        Entry(id: "hewitt_dining", schoolId: "barnard", name: "Hewitt Dining", latitude: 40.8095, longitude: -73.9633, address: "3009 Broadway, New York, NY 10027", city: "New York", state: "NY", geofenceRadius: 70, defaultOpenState: true, iconName: nil, menuMetadata: MenuMetadata(siteId: "5cb77d6e4198d40babbc28b5", locationId: "5d27a0461ca48e0aca2a104c", referer: "https://dineoncampus.com/barnard", userAgent: "CampusDash/1.0 (Hewitt)")),
        Entry(id: "barnard_kosher_hewitt", schoolId: "barnard", name: "Barnard Kosher @ Hewitt", latitude: 40.8095, longitude: -73.9633, address: "3009 Broadway, New York, NY 10027", city: "New York", state: "NY", geofenceRadius: 70, defaultOpenState: true, iconName: nil, menuMetadata: MenuMetadata(siteId: "5cb77d6e4198d40babbc28b5", locationId: "5d794b63c4b7ff15288ba3da", referer: "https://dineoncampus.com/barnard", userAgent: "CampusDash/1.0 (Kosher)")),
        Entry(id: "lefrak_center", schoolId: "barnard", name: "LeFrak Center", latitude: 40.8100, longitude: -73.9637, address: "35 Claremont Ave, New York, NY 10027", city: "New York", state: "NY", geofenceRadius: 60, defaultOpenState: true, iconName: nil, menuMetadata: MenuMetadata(siteId: "5cb77d6e4198d40babbc28b5", locationId: "67252a74351d530746aa3f21", referer: "https://dineoncampus.com/barnard", userAgent: "CampusDash/1.0 (LeFrak)")),
        Entry(id: "lizs_place", schoolId: "barnard", name: "Liz's Place", latitude: 40.8098, longitude: -73.9630, address: "The Diana Center, 3009 Broadway, New York, NY 10027", city: "New York", state: "NY", geofenceRadius: 60, defaultOpenState: true, iconName: nil, menuMetadata: MenuMetadata(siteId: "5cb77d6e4198d40babbc28b5", locationId: "63e6c3b1351d53062192e8a4", referer: "https://dineoncampus.com/barnard", userAgent: "CampusDash/1.0 (Lizs Place)")),
        Entry(id: "diana_center_cafe", schoolId: "barnard", name: "Diana Center Cafe", latitude: 40.8096, longitude: -73.9630, address: "The Diana Center, 3009 Broadway, New York, NY 10027", city: "New York", state: "NY", geofenceRadius: 60, defaultOpenState: true, iconName: nil, menuMetadata: MenuMetadata(siteId: "5cb77d6e4198d40babbc28b5", locationId: "5d8775484198d40d7a0b8078", referer: "https://dineoncampus.com/barnard", userAgent: "CampusDash/1.0 (Diana)")),
        Entry(id: "barnard_bubble_tea_sushi_milstein", schoolId: "barnard", name: "Bubble Tea & Sushi Spot", latitude: 40.8089, longitude: -73.9637, address: "Milstein Center, 535 W 116th St, New York, NY 10027", city: "New York", state: "NY", geofenceRadius: 60, defaultOpenState: true, iconName: nil, menuMetadata: MenuMetadata(siteId: "5cb77d6e4198d40babbc28b5", locationId: "63e6c3b1351d53062192e8a4", referer: "https://dineoncampus.com/barnard", userAgent: "CampusDash/1.0 (BubbleTea)"))
    ]

    static var entries: [Entry] { entriesBacking }

    static func entry(for id: String) -> Entry? {
        entriesBacking.first { $0.id == id }
    }

    static func entries(forSchoolId schoolId: String) -> [Entry] {
        entriesBacking.filter { $0.schoolId == schoolId }
    }

    static func menuMetadata(for hallId: String) -> MenuMetadata? {
        entry(for: hallId)?.menuMetadata
    }
}
