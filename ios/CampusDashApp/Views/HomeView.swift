import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                hallPicker
                windowPicker
                if let snapshot = viewModel.livePool {
                    LivePoolView(snapshot: snapshot)
                } else {
                    Text("Waiting for live data…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                orderButton
            }
            .padding()
            .navigationTitle("Order a Meal")
            .onChange(of: viewModel.selectedHall) { _, hall in
                appState.activeDiningHall = hall
                viewModel.subscribeToPool()
            }
            .onChange(of: viewModel.selectedWindow) { _, _ in
                viewModel.subscribeToPool()
            }
            .onAppear {
                viewModel.subscribeToPool()
            }
            .alert(item: Binding(
                get: { viewModel.errorMessage.map(ErrorMessage.init(value:)) },
                set: { viewModel.errorMessage = $0?.value }
            )) { message in
                Alert(title: Text("Error"), message: Text(message.value), dismissButton: .default(Text("OK")))
            }
        }
    }

    private var hallPicker: some View {
        Picker("Dining Hall", selection: $viewModel.selectedHall) {
            ForEach(viewModel.diningHalls, id: \.id) { hall in
                Text(hall.name).tag(Optional(hall))
            }
        }
        .pickerStyle(.menu)
    }

    private var windowPicker: some View {
        Picker("Window", selection: $viewModel.selectedWindow) {
            Text("Current").tag(ServiceWindowType.current)
            Text("Breakfast").tag(ServiceWindowType.breakfast)
            Text("Lunch").tag(ServiceWindowType.lunch)
            Text("Dinner").tag(ServiceWindowType.dinner)
        }
        .pickerStyle(.segmented)
    }

    private var orderButton: some View {
        Button(action: placeOrder) {
            if viewModel.isPlacingOrder {
                ProgressView()
            } else {
                Text("Place Order")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .disabled(viewModel.isPlacingOrder || appState.currentUser == nil)
    }

    private func placeOrder() {
        guard let user = appState.currentUser else { return }
        Task {
            await viewModel.createOrder(for: user)
        }
    }
}

struct LivePoolView: View {
    let snapshot: LivePoolSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Live Queue")
                .font(.headline)
            HStack {
                Label("\(snapshot.queueSize) waiting", systemImage: "person.2.fill")
                Spacer()
                Text("ETA: \(Int(snapshot.averageWaitSeconds / 60)) min")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
