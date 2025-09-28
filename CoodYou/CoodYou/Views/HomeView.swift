import SwiftUI
import MapKit
import UIKit
import Combine

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: HomeViewModel = HomeViewModel()

    private static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.8075, longitude: -73.9641),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    @State private var region = Self.defaultRegion
    @State private var selectedHall: DiningHall?
    @State private var checkoutHall: DiningHall?
    @State private var showingHandoff = false
    @State private var didApplyInitialSchool = false

    var body: some View {
        NavigationStack {
            mainContent
        }
        .sheet(isPresented: $showingHandoff) {
            handoffSheet
        }
        .sheet(item: $selectedHall) { hall in
            selectedHallSheet(hall: hall)
        }
        .sheet(item: $checkoutHall) { hall in
            checkoutHallSheet(hall: hall)
        }
        .task {
            if let user = appState.currentUser {
                viewModel.bindOrders(for: user.id)
            }
            if let hall = viewModel.selectedHall {
                region.center = hall.coordinate
            }
            viewModel.subscribeToPool()
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
        .onReceive(viewModel.$userLocation.compactMap { $0 }) { location in
            guard viewModel.selectedHall == nil else { return }
            withAnimation(.easeInOut(duration: 0.35)) {
                region.center = location
            }
        }
        .onChange(of: viewModel.activeSchoolFilter) { _, school in
            if let school, let firstHall = viewModel.halls(for: school).first {
                withAnimation(.easeInOut(duration: 0.35)) {
                    region.center = firstHall.coordinate
                }
            }
        }
        .onChange(of: appState.selectedSchool) { _, newSchool in
            if !didApplyInitialSchool {
                didApplyInitialSchool = true
                return
            }
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
        .alert(item: errorBinding) { message in
            Alert(title: Text("Error"), message: Text(message.value), dismissButton: .default(Text("OK")))
        }
    }

    private var mainContent: some View {
        ZStack(alignment: .top) {
            mapCanvas

            VStack(spacing: 12) {
                searchBar
                searchResults
            }
            .padding(.top, 16)
            .padding(.horizontal, 16)

            if viewModel.shouldShowHallPanel {
                hallListPanel
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

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

    private var errorBinding: Binding<ErrorMessage?> {
        Binding(
            get: { viewModel.errorMessage.map(ErrorMessage.init(value:)) },
            set: { viewModel.errorMessage = $0?.value }
        )
    }

    @ViewBuilder
    private var handoffSheet: some View {
        if let order = viewModel.activeOrder {
            HandoffView(order: order, run: nil)
                .environmentObject(appState)
        }
    }

    private func selectedHallSheet(hall: DiningHall) -> some View {
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

    private func checkoutHallSheet(hall: DiningHall) -> some View {
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

    private var mapCanvas: some View {
        let halls = viewModel.visibleHalls
        return Map(coordinateRegion: $region, interactionModes: [.all], showsUserLocation: true, annotationItems: halls) { hall in
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
                                    } label: {
                                        schoolRowResult(school: school)
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

    private var hallListPanel: some View {
        VStack(spacing: 16) {
            if let school = viewModel.activeSchoolFilter {
                HStack(spacing: 12) {
                    SchoolIconView(school: school, size: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(school.displayName)
                            .font(.headline)
                        Text("Tap a dining hall to explore menus and pin it on the map.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        Task { await viewModel.clearSearch(preserveFilter: false) }
                        viewModel.clearActiveSchool()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .imageScale(.medium)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Close hall panel")
                }
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.hallResults) { hall in
                        Button {
                            viewModel.selectHall(hall)
                            Task {
                                await viewModel.loadMenuIfNeeded(for: hall)
                            }
                            selectedHall = hall
                            withAnimation(.easeInOut(duration: 0.35)) {
                                region.center = hall.coordinate
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(accentColor(for: hall.schoolId))
                                    .imageScale(.large)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(hall.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(hall.address)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(Color(.systemBackground).opacity(0.92), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 280)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.18), radius: 24, y: 16)
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
