import Foundation
import Combine

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
    private let schoolService = SchoolService.shared
    private let hallService = DiningHallService.shared

    private var cartItems: [CartItem] = []
    private var cartHallId: String?

    private let orderService = OrderService.shared
    private let menuService = MenuService.shared
    private var cancellables: Set<AnyCancellable> = []
    private var ordersTask: Task<Void, Never>?
    private var ignoreSearchChanges = false

    init() {
        diningHalls = hallService.halls
        selectedHall = diningHalls.first

        Task {
            do {
                try await schoolService.ensureSchoolsLoaded()
                try await hallService.ensureHallsLoaded()
                await MainActor.run {
                    self.diningHalls = self.hallService.halls
                    if self.selectedHall == nil {
                        self.selectedHall = self.diningHalls.first
                    }
                    if let school = self.activeSchoolFilter {
                        self.hallResults = self.halls(for: school)
                    }
                }
                await bootstrapStatuses()
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }

        hallService.$halls
            .receive(on: RunLoop.main)
            .sink { [weak self] halls in
                self?.diningHalls = halls
                if self?.selectedHall == nil {
                    self?.selectedHall = halls.first
                }
            }
            .store(in: &cancellables)
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

    var hasResults: Bool {
        if !schoolResults.isEmpty || !hallResults.isEmpty { return true }
        if activeSchoolFilter != nil { return true }
        return false
    }

    func status(for hall: DiningHall) -> DiningHallStatus {
        if let cached = hallStatuses[hall.id] {
            return cached
        }
        let defaultMessage = hall.defaultOpenState ? "Open" : "Closed"
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
        for hall in diningHalls where !hall.menuIds.isEmpty {
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

    func search(query: String, debounced: Bool = true) {
        if ignoreSearchChanges { return }
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            Task { await clearSearch(preserveFilter: false) }
            return
        }

        isSearching = true
        activeSchoolFilter = nil

        let task = Task { @MainActor [weak self] in
            if debounced {
                try? await Task.sleep(nanoseconds: 220_000_000)
            }
            guard let self else { return }
            do {
                try await self.schoolService.ensureSchoolsLoaded()
                try await self.hallService.ensureHallsLoaded()

                let lower = trimmed.lowercased()
                let tokens = lower.split(whereSeparator: { $0 == " " || $0 == "," }).map(String.init)

                let schools = self.schoolService.schools.filter { school in
                    let haystack = (school.displayName + " " + school.name).lowercased()
                    return tokens.allSatisfy { haystack.contains($0) }
                }

                let halls = self.hallService.halls.filter { hall in
                    self.matches(hall: hall, queryTokens: tokens)
                }

                self.schoolResults = schools
                self.hallResults = halls
                self.isSearching = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isSearching = false
            }
        }
        searchTask = task
    }

    func halls(for school: School) -> [DiningHall] {
        let ids = Set(school.diningHallIds + school.primaryDiningHallIds)
        if !ids.isEmpty {
            let matched = hallService.halls.filter { ids.contains($0.id) }
            if !matched.isEmpty { return matched }
        }
        return hallService.halls.filter { $0.schoolId == school.id }
    }

    func school(for hall: DiningHall) -> School? {
        schoolService.school(withId: hall.schoolId)
    }

    var visibleHalls: [DiningHall] {
        if let filter = activeSchoolFilter {
            return halls(for: filter)
        }
        if !hallResults.isEmpty {
            return hallResults
        }
        return diningHalls
    }

    func activateSchool(_ school: School) {
        activeSchoolFilter = school
        let hallsForSchool = halls(for: school)
        hallResults = hallsForSchool
        schoolResults = []
        if let first = hallsForSchool.first {
            selectedHall = first
        }
        isSearching = false
        ignoreSearchChanges = true
        searchText = ""
        ignoreSearchChanges = false
    }

    func selectHall(_ hall: DiningHall) {
        selectedHall = hall
        activeSchoolFilter = school(for: hall)
    }

    func clearSearch(preserveFilter: Bool = false) async {
        ignoreSearchChanges = true
        searchTask?.cancel()
        searchText = ""
        schoolResults = []
        if !preserveFilter {
            hallResults = []
        }
        isSearching = false
        if !preserveFilter {
            activeSchoolFilter = nil
        }
        await Task.yield()
        ignoreSearchChanges = false
    }
    private func matches(hall: DiningHall, queryTokens: [String]) -> Bool {
        if queryTokens.isEmpty { return false }
        let haystack = [hall.name, hall.campus, hall.address, hall.city, hall.state]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
        return queryTokens.allSatisfy { haystack.contains($0) }
    }

    private func bucket(for hall: DiningHall) -> Int {
        hallIsOpen(hall) ? 0 : 1
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
