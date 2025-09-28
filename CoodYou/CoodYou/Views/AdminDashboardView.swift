import SwiftUI
import FirebaseFirestore

struct AdminDashboardView: View {
    @State private var halls: [DiningHall] = []
    @State private var selectedHall: DiningHall?
    @State private var windowConfig = ServiceWindowConfig.default
    @State private var platformFee: Double = 0
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var queueSnapshot: LivePoolSnapshot?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    hallSelector
                    queueCard
                    windowEditor
                    platformFeeCard
                    toolsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Admin console")
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadInitialData() }
            .alert(item: Binding(
                get: { errorMessage.map(ErrorMessage.init(value:)) },
                set: { errorMessage = $0?.value }
            )) { message in
                Alert(title: Text("Error"), message: Text(message.value), dismissButton: .default(Text("OK")))
            }
        }
    }

    private var hallSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Dining hall")
                    .font(.headline)
                Spacer()
                Button("Refresh") { Task { await loadInitialData() } }
                    .font(.footnote)
            }
            Picker("Dining Hall", selection: $selectedHall) {
                ForEach(halls, id: \.id) { hall in
                    Text(hall.name).tag(Optional(hall))
                }
            }
            .pickerStyle(.wheel)
        }
        .padding(20)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 16, y: 12)
    }

    private var queueCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Live queue")
                    .font(.headline)
                Spacer()
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
            }
            if let snapshot = queueSnapshot {
                HStack(spacing: 20) {
                    AdminMetric(title: "Waiting", value: "\(snapshot.queueSize)")
                    AdminMetric(title: "Avg wait", value: "\(Int(snapshot.averageWaitSeconds / 60)) min")
                    AdminMetric(title: "Window", value: snapshot.windowType.rawValue.capitalized)
                }
            } else {
                Text("No live data yet")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button {
                Task { await refreshQueue() }
            } label: {
                Label("Pull latest snapshot", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var windowEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Service windows")
                .font(.headline)
            windowRow(title: "Breakfast", range: $windowConfig.breakfast)
            windowRow(title: "Lunch", range: $windowConfig.lunch)
            windowRow(title: "Dinner", range: $windowConfig.dinner)
            Button {
                Task { await saveWindows() }
            } label: {
                Text("Save overrides")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedHall == nil)
        }
        .padding(24)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var platformFeeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Platform fee")
                .font(.headline)
            Text("Current: $\(platformFee, specifier: "%.2f")")
                .font(.title3.weight(.semibold))
            Slider(value: $platformFee, in: 0...5, step: 0.25)
            Button {
                Task { await updatePlatformFee() }
            } label: {
                Text("Update fee")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedHall == nil)
        }
        .padding(24)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Operational tools")
                .font(.headline)
            Button {
                Task { await triggerReprice() }
            } label: {
                Label("Recalculate pooled pricing", systemImage: "slider.horizontal.3")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                Task { await dissolvePairs() }
            } label: {
                Label("Force dissolve idle pairs", systemImage: "person.2.slash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func windowRow(title: String, range: Binding<ServiceWindowConfig.WindowRange>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text("\(range.wrappedValue.startHour):00 – \(range.wrappedValue.endHour):00")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Stepper("") {
                adjustWindow(&range.wrappedValue, delta: 1)
            } onDecrement: {
                adjustWindow(&range.wrappedValue, delta: -1)
            }
            .labelsHidden()
        }
    }

    private func adjustWindow(_ window: inout ServiceWindowConfig.WindowRange, delta: Int) {
        let newStart = max(0, min(23, window.startHour + delta))
        let newEnd = max(newStart + 1, min(24, window.endHour + delta))
        window = .init(startHour: newStart, endHour: newEnd)
    }

    @MainActor
    private func loadInitialData() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let snapshot = try await FirebaseManager.shared.db.collection("dining_halls").getDocuments()
            let halls = snapshot.documents.map { doc -> DiningHall in
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
                    geofenceRadius: data["geofenceRadius"] as? Double ?? 75,
                    address: data["address"] as? String ?? "",
                    dineOnCampusSiteId: data["dineOnCampusSiteId"] as? String,
                    dineOnCampusLocationId: data["dineOnCampusLocationId"] as? String,
                    affiliation: DiningHallAffiliation(rawValue: data["affiliation"] as? String ?? DiningHallAffiliation.columbia.rawValue) ?? .columbia,
                    defaultOpenState: data["defaultOpenState"] as? Bool ?? true
                )
            }
            await MainActor.run {
                self.halls = halls
                if self.selectedHall == nil {
                    self.selectedHall = halls.first
                }
            }
            await refreshQueue()
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func refreshQueue() async {
        guard let hall = selectedHall else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let doc = try await FirebaseManager.shared.db.collection("hallPools")
                .document("\(hall.id)_\(ServiceWindowType.determineWindow(config: .default).rawValue)")
                .getDocument()
            if doc.exists {
                queueSnapshot = try doc.data(as: LivePoolSnapshot.self)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
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

    @MainActor
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

    @MainActor
    private func triggerReprice() async {
        do {
            try await withCheckedThrowingContinuation { continuation in
                let callable = FirebaseManager.shared.functions.httpsCallable("repriceDiningWindow")
                Task {
                    do {
                        let result = try await callable.call([:])
                        _ = result // Handle the result
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func dissolvePairs() async {
        guard let hall = selectedHall else { return }
        do {
            try await withCheckedThrowingContinuation { continuation in
                let callable = FirebaseManager.shared.functions.httpsCallable("dissolvePairs")
                Task {
                    do {
                        let result = try await callable.call(["hallId": hall.id])
                        _ = result // Handle the result
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AdminMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
