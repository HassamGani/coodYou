import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var diningHalls: [DiningHall]
    @Published var selectedHall: DiningHall?
    @Published var selectedWindow: ServiceWindowType = .current
    @Published var livePool: LivePoolSnapshot?
    @Published var activeOrder: Order?
    @Published var isPlacingOrder = false
    @Published var errorMessage: String?

    @Published private(set) var menus: [String: DiningHallMenu] = [:]
    @Published private(set) var loadingMenuIds: Set<String> = []
    @Published private(set) var menuErrors: [String: String] = [:]
    @Published private(set) var hallStatuses: [String: DiningHallStatus] = [:]

    // --- Search state ---
    @Published var searchText: String = ""
    @Published var isSearching: Bool = false
    @Published var schoolResults: [School] = []
    @Published var hallResults: [DiningHall] = []

    // When non-nil, the UI should show only halls for this school (set by tapping a school in search)
    @Published var activeSchoolFilter: School?


    private var searchTask: Task<Void, Never>?
    private let db = FirebaseManager.shared.db

    private var cartItems: [CartItem] = []
    private var cartHallId: String?

    private let orderService = OrderService.shared
    private let menuService = MenuService.shared
    private var cancellables: Set<AnyCancellable> = []
    private var ordersTask: Task<Void, Never>?

    init() {
        let allHalls = DiningHallDirectory.all
        diningHalls = allHalls
        selectedHall = sortedHalls.first
        Task {
            await bootstrapStatuses()
            await loadRemoteDiningHalls()
        }
    }

    deinit {
        ordersTask?.cancel()
        orderService.stopListening()
    }

    var sortedHalls: [DiningHall] {
        diningHalls.sorted { lhs, rhs in
            let lhsBucket = bucket(for: lhs)
            let rhsBucket = bucket(for: rhs)
            if lhsBucket != rhsBucket { return lhsBucket < rhsBucket }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    var displayWindow: ServiceWindowType {
        selectedWindow == .current ? ServiceWindowType.determineWindow(config: .default) : selectedWindow
    }

    func status(for hall: DiningHall) -> DiningHallStatus {
        if let cached = hallStatuses[hall.id] {
            return cached
        }
        let defaultMessage: String
        if hall.affiliation == .columbia && hall.dineOnCampusLocationId == nil {
            defaultMessage = "Menu coming soon"
        } else {
            defaultMessage = hall.defaultOpenState ? "Open" : "Closed"
        }
        return DiningHallStatus(
            isOpen: hall.defaultOpenState,
            statusMessage: defaultMessage,
            currentPeriodName: nil,
            periodRangeText: nil
        )
    }

    func menu(for hall: DiningHall) -> DiningHallMenu? {
        menus[hall.id]
    }

    func isLoadingMenu(for hall: DiningHall) -> Bool {
        loadingMenuIds.contains(hall.id)
    }

    func menuError(for hall: DiningHall) -> String? {
        menuErrors[hall.id]
    }

    func loadMenuIfNeeded(for hall: DiningHall) async {
        if menus[hall.id] != nil || loadingMenuIds.contains(hall.id) { return }
        loadingMenuIds.insert(hall.id)
        do {
            let menu = try await menuService.menu(for: hall)
            menus[hall.id] = menu
            hallStatuses[hall.id] = menu.status
        } catch {
            menuErrors[hall.id] = error.localizedDescription
            hallStatuses[hall.id] = DiningHallStatus(
                isOpen: hall.defaultOpenState,
                statusMessage: "Unable to load menu",
                currentPeriodName: nil,
                periodRangeText: nil
            )
        }
        loadingMenuIds.remove(hall.id)
        selectedHall = selectedHall ?? hall
    }

    func bootstrapStatuses() async {
        for hall in diningHalls where hall.affiliation == .barnard {
            await loadMenuIfNeeded(for: hall)
        }
    }

    func hallIsOpen(_ hall: DiningHall) -> Bool {
        status(for: hall).isOpen
    }

    func cartItems(for hall: DiningHall) -> [CartItem] {
        cartItems.filter { $0.hallId == hall.id }
    }

    func addToCart(item: DiningHallMenu.MenuItem, hall: DiningHall) {
        if cartHallId != hall.id {
            cartItems.removeAll()
            cartHallId = hall.id
        }
        cartItems.append(CartItem(hallId: hall.id, name: item.name))
    }

    func removeFromCart(_ item: CartItem) {
        cartItems.removeAll { $0.id == item.id }
        if cartItems.isEmpty {
            cartHallId = nil
        }
    }

    func clearCart(for hall: DiningHall) {
        cartItems.removeAll { $0.hallId == hall.id }
        if cartHallId == hall.id { cartHallId = nil }
    }

    func hasCart(for hall: DiningHall) -> Bool {
        !cartItems(for: hall).isEmpty
    }

    func cartCount(for hall: DiningHall) -> Int {
        cartItems(for: hall).count
    }

    func subscribeToPool() {
        guard let hall = selectedHall else { return }
        orderService.startListeningToPool(hallId: hall.id, window: displayWindow)
        cancellables.removeAll()
        orderService.$livePools
            .receive(on: RunLoop.main)
            .sink { [weak self] pools in
                self?.livePool = pools.first
            }
            .store(in: &cancellables)
    }

    func bindOrders(for uid: String) {
        ordersTask?.cancel()
        ordersTask = Task {
            do {
                for try await orders in orderService.subscribeToOrders(uid: uid) {
                    let active = orders
                        .filter { !$0.isTerminal }
                        .sorted(by: { $0.createdAt > $1.createdAt })
                        .first
                    await MainActor.run {
                        self.activeOrder = active
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func createOrder(for user: UserProfile, isSoloFallback: Bool = false) async {
        guard let hall = selectedHall else { return }
        isPlacingOrder = true
        defer { isPlacingOrder = false }

        let price = price(for: hall, window: displayWindow, soloFallback: isSoloFallback)
        let order = Order(
            id: UUID().uuidString,
            userId: user.id,
            hallId: hall.id,
            status: .requested,
            windowType: displayWindow,
            priceCents: Int(price * 100),
            createdAt: Date(),
            pairGroupId: nil,
            meetPoint: nil,
            pinCode: String(UUID().uuidString.prefix(6)),
            isSoloFallback: isSoloFallback
        )

        do {
            try await orderService.createOrder(order)
            clearCart(for: hall)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelActiveOrder(_ order: Order) async {
        do {
            try await orderService.cancelOrder(orderId: order.id)
            activeOrder = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func displayPrice(for hall: DiningHall) -> String {
        let price = price(for: hall, window: displayWindow, soloFallback: false)
        return String(format: "$%.2f", price)
    }

    func splitPriceLabel(for hall: DiningHall) -> String {
        let actual = price(for: hall, window: displayWindow, soloFallback: false) - 0.50
        return String(format: "$%.2f", actual)
    }

    func orderPitch(for hall: DiningHall?) -> String {
        guard let hall else { return "Pick a dining hall to see active dashers and live timing." }
        return "Dashers currently in \(hall.name) can grab your meal in minutes. Pair with a nearby student to split the price."
    }

    // MARK: - Search

    func search(query: String) {
        searchTask?.cancel()
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Task { await clearSearch() }
            return
        }

        isSearching = true
        searchTask = Task { [weak self] in
            guard let strongSelf = self else { return }
            // Simple client-side substring match for cached schools/halls first
            let lower = query.lowercased()
            // Query schools collection by displayName and name (prefix search)
            do {
                var fetchedSchools: [School] = []
                let schoolsSnap = try await db.collection("schools")
                    .whereField("active", isEqualTo: true)
                    .getDocuments()
                for doc in schoolsSnap.documents {
                    let d = doc.data()
                    let school = School(
                        id: doc.documentID,
                        name: d["name"] as? String ?? "",
                        displayName: d["displayName"] as? String ?? (d["name"] as? String ?? ""),
                        allowedEmailDomains: d["allowedDomains"] as? [String] ?? [],
                        campusIconName: d["campusIconName"] as? String ?? "building.columns",
                        city: d["city"] as? String ?? "",
                        state: d["state"] as? String ?? "",
                        country: d["country"] as? String ?? "USA",
                        primaryDiningHallIds: d["primaryDiningHallIds"] as? [String] ?? []
                    )
                    if school.displayName.lowercased().contains(lower) || school.name.lowercased().contains(lower) {
                        fetchedSchools.append(school)
                    }
                }
                let hallMatches = await MainActor.run { strongSelf.filteredDiningHalls(matching: lower) }
                await MainActor.run {
                    strongSelf.schoolResults = fetchedSchools
                    strongSelf.hallResults = hallMatches
                    strongSelf.isSearching = false
                    // don't change selectedHall here; let the UI drive selection when user taps
                }
            } catch {
                await MainActor.run {
                    strongSelf.errorMessage = error.localizedDescription
                    strongSelf.isSearching = false
                }
            }
        }
    }

    func halls(for school: School) -> [DiningHall] {
        let ids = Set(school.primaryDiningHallIds)
        if !ids.isEmpty {
            let matched = diningHalls.filter { ids.contains($0.id) }
            if !matched.isEmpty { return matched }
        }

        // Fallback: try to infer by affiliation or campus name when primaryDiningHallIds are not provided
        let loweredName = (school.displayName + " " + school.name + " " + school.id).lowercased()
        if loweredName.contains("columbia") {
            return diningHalls.filter { $0.affiliation == .columbia }
        }
        if loweredName.contains("barnard") {
            return diningHalls.filter { $0.affiliation == .barnard }
        }

        // Final fallback: match diningHall.campus against school's displayName tokens
        let tokens = loweredName.split(whereSeparator: { $0 == " " || $0 == "," }) .map(String.init)
        return diningHalls.filter { hall in
            let hallCampus = hall.campus.lowercased()
            for t in tokens where !t.isEmpty {
                if hallCampus.contains(t) { return true }
            }
            return false
        }
    }

    func clearSearch() async {
        searchTask?.cancel()
        await MainActor.run {
            self.searchText = ""
            self.schoolResults = []
            self.hallResults = []
            self.isSearching = false
        }
    }

    private func loadRemoteDiningHalls() async {
        do {
            let documents = try await fetchDiningHallDocuments()
            guard !documents.isEmpty else { return }

            let remoteHalls = documents.compactMap { makeDiningHall(from: $0) }
            guard !remoteHalls.isEmpty else { return }

            diningHalls = remoteHalls

            if let currentSelection = selectedHall {
                selectedHall = remoteHalls.first(where: { $0.id == currentSelection.id }) ?? sortedHalls.first
            } else {
                selectedHall = sortedHalls.first
            }

            if let school = activeSchoolFilter {
                hallResults = halls(for: school)
            } else if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                hallResults = filteredDiningHalls(matching: searchText.lowercased())
            }

            await bootstrapStatuses()
        } catch {
            // Keep the static directory fallback when Firestore fetch fails.
        }
    }

    private func fetchDiningHallDocuments() async throws -> [QueryDocumentSnapshot] {
        let candidates = ["dining_halls", "diningHalls"]
        for name in candidates {
            do {
                let snapshot = try await db.collection(name).getDocuments()
                if !snapshot.documents.isEmpty {
                    return snapshot.documents
                }
            } catch {
                if name == candidates.last {
                    throw error
                }
            }
        }
        return []
    }

    private func makeDiningHall(from document: QueryDocumentSnapshot) -> DiningHall? {
        let data = document.data()
        let isActive = (data["active"] as? Bool) ?? true
        guard isActive else { return nil }

        let latitude = doubleValue(data["latitude"]) ?? 0
        let longitude = doubleValue(data["longitude"]) ?? 0
        let radius = doubleValue(data["geofenceRadius"]) ?? doubleValue(data["geofence_radius"]) ?? 75

        let breakfast = doubleValue(data["price_breakfast"]) ?? doubleValue(data["priceBreakfast"]) ?? DiningHallPrice.standard.breakfast
        let lunch = doubleValue(data["price_lunch"]) ?? doubleValue(data["priceLunch"]) ?? DiningHallPrice.standard.lunch
        let dinner = doubleValue(data["price_dinner"]) ?? doubleValue(data["priceDinner"]) ?? DiningHallPrice.standard.dinner

        let affiliationValue = (data["affiliation"] as? String) ?? (data["campus"] as? String) ?? "columbia"
        let loweredAffiliation = affiliationValue.lowercased()
        let affiliation = DiningHallAffiliation(rawValue: loweredAffiliation)
            ?? (loweredAffiliation.contains("barnard") ? .barnard : .columbia)

        let defaultOpenState = (data["defaultOpenState"] as? Bool)
            ?? (data["default_open_state"] as? Bool)
            ?? true

        return DiningHall(
            id: document.documentID,
            name: data["name"] as? String ?? document.documentID,
            campus: data["campus"] as? String ?? "",
            latitude: latitude,
            longitude: longitude,
            active: isActive,
            price: DiningHallPrice(breakfast: breakfast, lunch: lunch, dinner: dinner),
            geofenceRadius: radius,
            address: data["address"] as? String ?? "",
            dineOnCampusSiteId: data["dineOnCampusSiteId"] as? String ?? data["dine_on_campus_site_id"] as? String,
            dineOnCampusLocationId: data["dineOnCampusLocationId"] as? String ?? data["dine_on_campus_location_id"] as? String,
            affiliation: affiliation,
            defaultOpenState: defaultOpenState
        )
    }

    private func filteredDiningHalls(matching lowercasedQuery: String) -> [DiningHall] {
        let trimmed = lowercasedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let tokens = trimmed.split(whereSeparator: { $0 == " " || $0 == "," }).map { String($0) }

        return diningHalls.filter { hall in
            let fields = [hall.name, hall.campus, hall.address].map { $0.lowercased() }
            if fields.contains(where: { $0.contains(trimmed) }) {
                return true
            }
            guard !tokens.isEmpty else { return false }
            return fields.contains { field in
                tokens.contains(where: { token in field.contains(token.lowercased()) })
            }
        }
    }

    private func doubleValue(_ value: Any?) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let string = value as? String {
            return Double(string)
        }
        return nil
    }

    private func bucket(for hall: DiningHall) -> Int {
        let isOpen = hallIsOpen(hall)
        switch (hall.affiliation, isOpen) {
        case (.columbia, true): return 0
        case (.barnard, true): return 1
        case (.columbia, false): return 2
        case (.barnard, false): return 3
        }
    }

    private func price(for hall: DiningHall, window: ServiceWindowType, soloFallback: Bool) -> Double {
        let actualWindow = window == .current ? ServiceWindowType.determineWindow(config: .default) : window
        let basePrice: Double
        switch actualWindow {
        case .breakfast: basePrice = hall.price.breakfast
        case .lunch: basePrice = hall.price.lunch
        case .dinner: basePrice = hall.price.dinner
        case .current: basePrice = hall.price.lunch
        }
        if soloFallback {
            return basePrice * 0.75 + 0.50
        }
        return basePrice / 2 + 0.50
    }
}
