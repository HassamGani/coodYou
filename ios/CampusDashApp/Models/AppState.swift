import Foundation
import Combine

final class AppState: ObservableObject {
    @Published var currentUser: UserProfile?
    @Published var activeRole: UserRole = .buyer
    @Published var activeDiningHall: DiningHall?
    @Published var activeWindow: ServiceWindowType = .current
    @Published var activeRun: Run?
    @Published var pendingOrders: [Order] = []
    @Published var dasherAssignments: [Run] = []

    func reset() {
        currentUser = nil
        activeRun = nil
        pendingOrders = []
        dasherAssignments = []
    }
}
