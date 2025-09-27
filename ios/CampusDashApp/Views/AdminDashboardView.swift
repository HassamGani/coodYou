import SwiftUI

struct AdminDashboardView: View {
    @State private var halls: [DiningHall] = []
    @State private var selectedHall: DiningHall?
    @State private var windowConfig = ServiceWindowConfig.default
    @State private var platformFee: Double = 0
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section("Dining Halls") {
                    Picker("Select", selection: $selectedHall) {
                        ForEach(halls, id: \.id) { hall in
                            Text(hall.name).tag(Optional(hall))
                        }
                    }
                    Button("Refresh") { Task { await loadHalls() } }
                }

                Section("Service Windows") {
                    Stepper(
                        "Breakfast: \(windowConfig.breakfast.startHour)-\(windowConfig.breakfast.endHour)",
                        onIncrement: { adjustWindow(&windowConfig.breakfast, delta: 1) },
                        onDecrement: { adjustWindow(&windowConfig.breakfast, delta: -1) }
                    )
                    Stepper(
                        "Lunch: \(windowConfig.lunch.startHour)-\(windowConfig.lunch.endHour)",
                        onIncrement: { adjustWindow(&windowConfig.lunch, delta: 1) },
                        onDecrement: { adjustWindow(&windowConfig.lunch, delta: -1) }
                    )
                    Stepper(
                        "Dinner: \(windowConfig.dinner.startHour)-\(windowConfig.dinner.endHour)",
                        onIncrement: { adjustWindow(&windowConfig.dinner, delta: 1) },
                        onDecrement: { adjustWindow(&windowConfig.dinner, delta: -1) }
                    )
                    Button("Save Windows") { Task { await saveWindows() } }
                }

                Section("Platform Fee") {
                    HStack {
                        Slider(value: $platformFee, in: 0...5, step: 0.25)
                        Text("$\(platformFee, specifier: "%.2f")")
                    }
                    Button("Update Fee") { Task { await updatePlatformFee() } }
                }
            }
            .navigationTitle("Admin Console")
            .task { await loadHalls() }
            .alert(item: Binding(
                get: { errorMessage.map(ErrorMessage.init(value:)) },
                set: { errorMessage = $0?.value }
            )) { message in
                Alert(title: Text("Error"), message: Text(message.value), dismissButton: .default(Text("OK")))
            }
        }
    }

    private func loadHalls() async {
        do {
            let snapshot = try await FirebaseManager.shared.db.collection("dining_halls").getDocuments()
            let halls = try snapshot.documents.map { doc -> DiningHall in
                let data = doc.data()
                return DiningHall(
                    id: doc.documentID,
                    name: data["name"] as? String ?? "",
                    campus: data["campus"] as? String ?? "",
                    latitude: data["latitude"] as? Double ?? 0,
                    longitude: data["longitude"] as? Double ?? 0,
                    active: data["active"] as? Bool ?? false,
                    price: DiningHallPrice(
                        breakfast: data["price_breakfast"] as? Double ?? 0,
                        lunch: data["price_lunch"] as? Double ?? 0,
                        dinner: data["price_dinner"] as? Double ?? 0
                    ),
                    geofenceRadius: data["geofenceRadius"] as? Double ?? 75
                )
            }
            self.halls = halls
            selectedHall = halls.first
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func adjustWindow(_ window: inout ServiceWindowConfig.WindowRange, delta: Int) {
        let newStart = max(0, min(23, window.startHour + delta))
        let newEnd = max(newStart + 1, min(24, window.endHour + delta))
        window = .init(startHour: newStart, endHour: newEnd)
    }

    private func saveWindows() async {
        guard let hall = selectedHall else { return }
        do {
            try await FirebaseManager.shared.db.collection("service_windows")
                .document(hall.id)
                .setData([
                    "breakfast": ["start": windowConfig.breakfast.startHour, "end": windowConfig.breakfast.endHour],
                    "lunch": ["start": windowConfig.lunch.startHour, "end": windowConfig.lunch.endHour],
                    "dinner": ["start": windowConfig.dinner.startHour, "end": windowConfig.dinner.endHour]
                ])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updatePlatformFee() async {
        guard let hall = selectedHall else { return }
        do {
            try await FirebaseManager.shared.db.collection("config")
                .document("platform_fee")
                .setData([hall.id: platformFee], merge: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
