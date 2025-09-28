import SwiftUI
import MapKit
import UIKit

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = HomeViewModel()

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.8075, longitude: -73.9641),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var selectedHall: DiningHall?
    @State private var checkoutHall: DiningHall?
    @State private var showingHandoff = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                mapCanvas

                VStack(spacing: 12) {
                    searchBar
                    searchResults
                }
                .padding(.top, 16)
                .padding(.horizontal, 16)

                if let order = viewModel.activeOrder, !order.isTerminal {
                    ActiveOrderOverlay(order: order) {
                        showingHandoff = true
                    }
                    .padding(.bottom, 32)
                    .padding(.trailing, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingHandoff) {
            if let order = viewModel.activeOrder {
                HandoffView(order: order, run: nil)
                    .environmentObject(appState)
            }
        }
        .sheet(item: $selectedHall) { hall in
            NavigationStack {
                DiningHallDetailView(hall: hall,
                                     viewModel: viewModel,
                                     checkoutHall: $checkoutHall)
                    .navigationTitle(hall.name)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Close") { selectedHall = nil }
                        }
                    }
            }
        }
        .sheet(item: $checkoutHall) { hall in
            NavigationStack {
                CheckoutView(hall: hall, viewModel: viewModel)
                    .environmentObject(appState)
                    .navigationTitle("Checkout")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { checkoutHall = nil }
                        }
                    }
            }
        }
        .task {
            if let user = appState.currentUser {
                viewModel.bindOrders(for: user.id)
            }
            if let hall = viewModel.selectedHall {
                region.center = hall.coordinate
            }
            viewModel.subscribeToPool()
            if let school = appState.selectedSchool {
                viewModel.activateSchool(school)
                if let anchor = viewModel.halls(for: school).first {
                    region.center = anchor.coordinate
                }
            }
        }
        .onChange(of: appState.currentUser?.id) { _, newValue in
            guard let newValue else { return }
            viewModel.bindOrders(for: newValue)
        }
        .onChange(of: viewModel.selectedHall) { _, hall in
            guard let hall else { return }
            withAnimation(.easeInOut(duration: 0.35)) {
                region.center = hall.coordinate
            }
            viewModel.subscribeToPool()
        }
        .onChange(of: viewModel.activeSchoolFilter) { _, school in
            if let school, let firstHall = viewModel.halls(for: school).first {
                withAnimation(.easeInOut(duration: 0.35)) {
                    region.center = firstHall.coordinate
                }
            }
        }
        .onChange(of: appState.selectedSchool) { _, newSchool in
            if let school = newSchool {
                viewModel.activateSchool(school)
                if let anchor = viewModel.halls(for: school).first {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        region.center = anchor.coordinate
                    }
                }
            } else {
                viewModel.activeSchoolFilter = nil
            }
        }
        .alert(item: Binding(
            get: { viewModel.errorMessage.map(ErrorMessage.init(value:)) },
            set: { viewModel.errorMessage = $0?.value }
        )) { message in
            Alert(title: Text("Error"), message: Text(message.value), dismissButton: .default(Text("OK")))
        }
    }

    private var mapCanvas: some View {
        Map(coordinateRegion: $region, interactionModes: [.all], showsUserLocation: true, annotationItems: viewModel.visibleHalls) { hall in
            MapAnnotation(coordinate: hall.coordinate) {
                HallPin(isSelected: viewModel.selectedHall?.id == hall.id,
                        tint: accentColor(for: hall.schoolId))
                .onTapGesture {
                    viewModel.selectHall(hall)
                    Task { await viewModel.loadMenuIfNeeded(for: hall) }
                    selectedHall = hall
                }
            }
        }
        .mapStyle(.standard(elevation: .automatic))
        .ignoresSafeArea()
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search schools or dining halls", text: $viewModel.searchText)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .submitLabel(.search)
                .onSubmit { viewModel.search(query: viewModel.searchText, debounced: false) }
            if !viewModel.searchText.isEmpty {
                Button {
                    Task { await viewModel.clearSearch() }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 18, y: 12)
        .onChange(of: viewModel.searchText) { text in
            viewModel.search(query: text)
        }
    }

    private var searchResults: some View {
        Group {
            if viewModel.isSearching {
                ProgressView()
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else if viewModel.hasResults {
                ScrollView {
                    VStack(spacing: 0) {
                        if !viewModel.schoolResults.isEmpty {
                            Section(header: resultsHeader(title: "Schools")) {
                                ForEach(viewModel.schoolResults) { school in
                                    Button {
                                        viewModel.activateSchool(school)
                                        Task { await viewModel.clearSearch(preserveFilter: true) }
                                    } label: {
                                        schoolRowResult(school: school)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        if !viewModel.hallResults.isEmpty {
                            Section(header: resultsHeader(title: "Dining Halls")) {
                                ForEach(viewModel.hallResults) { hall in
                                    Button {
                                        viewModel.selectHall(hall)
                                        Task {
                                            await viewModel.clearSearch(preserveFilter: true)
                                            await viewModel.loadMenuIfNeeded(for: hall)
                                        }
                                        selectedHall = hall
                                        withAnimation(.easeInOut(duration: 0.35)) {
                                            region.center = hall.coordinate
                                        }
                                    } label: {
                                        resultRow(title: hall.name,
                                                  subtitle: hall.address,
                                                  icon: "fork.knife")
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.black.opacity(0.12), radius: 18, y: 12)
            }
        }
    }

    private func resultsHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.bottom, 8)
    }

    private func resultRow(title: String, subtitle: String, icon: String?) -> some View {
        HStack(spacing: 12) {
            if let icon, !icon.isEmpty, UIImage(systemName: icon) != nil {
                Image(systemName: icon)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(Color.accentColor)
            } else {
                fallbackIcon(for: title)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(10)
        .background(Color(.systemBackground).opacity(0.9), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func fallbackIcon(for title: String) -> some View {
        Circle()
            .fill(Color.accentColor.opacity(0.12))
            .frame(width: 28, height: 28)
            .overlay(
                Text(String(title.prefix(1)).uppercased())
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Color.accentColor)
            )
    }

    private func schoolRowResult(school: School) -> some View {
        resultRow(title: school.displayName,
                  subtitle: "@" + school.allowedEmailDomains.joined(separator: ", @"),
                  icon: validSystemIconName(from: school.iconName))
    }

    private func validSystemIconName(from iconName: String?) -> String? {
        guard let iconName, UIImage(systemName: iconName) != nil else { return nil }
        return iconName
    }

    private func accentColor(for schoolId: String) -> Color {
        let lowered = schoolId.lowercased()
        if lowered.contains("barnard") { return Color.purple }
        if lowered.contains("columbia") { return Color.blue }
        return Color.accentColor
    }
}

private struct HallPin: View {
    var isSelected: Bool
    var tint: Color

    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(tint)
                .frame(width: isSelected ? 16 : 12, height: isSelected ? 16 : 12)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .shadow(color: tint.opacity(0.4), radius: 6, y: 4)
            Triangle()
                .fill(tint)
                .frame(width: 8, height: 6)
                .rotationEffect(.degrees(180))
        }
        .padding(4)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct ActiveOrderOverlay: View {
    let order: Order
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Active order")
                        .font(.subheadline.weight(.semibold))
                    Text("PIN \(order.pinCode)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: Color.black.opacity(0.2), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
    }
}
