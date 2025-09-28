import SwiftUI

struct SchoolSelectionView: View {
    @EnvironmentObject private var appState: AppState
    @State private var errorMessage: String?
    @State private var isUpdating = false
    @State private var selectedSchool: School = SchoolDirectory.columbia
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("Choose your campus")
                .font(.largeTitle.weight(.bold))
            Text("CampusDash is piloting at Columbia and Barnard. Pick your school to unlock dining halls, geofences, and notifications.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
        }
        .padding(.top, 60)
    }
    
    private func emailDomainsText(for school: School) -> String {
        school.allowedEmailDomains.map { "@\($0)" }.joined(separator: ", ")
    }
    
    private func schoolRow(for school: School) -> some View {
        HStack {
            Image(systemName: school.campusIconName)
                .frame(width: 32)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(school.name)
                    .font(.headline)
                Text(emailDomainsText(for: school))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if selectedSchool.id == school.id {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedSchool = school
        }
    }
    
    private var schoolList: some View {
        List {
            ForEach(SchoolDirectory.all, id: \.id) { school in
                schoolRow(for: school)
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private var continueButton: some View {
        Button {
            Task { await updateSchool() }
        } label: {
            if isUpdating {
                ProgressView()
            } else {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 24)
            }
        }
        .disabled(isUpdating)
    }

    var body: some View {
        VStack(spacing: 24) {
            headerSection
            schoolList
            continueButton
            Spacer()
        }
        .navigationBarHidden(true)
        .task {
            if let existing = appState.selectedSchool {
                selectedSchool = existing
            }
        }
        .alert(item: Binding(
            get: { errorMessage.map(ErrorMessage.init(value:)) },
            set: { errorMessage = $0?.value }
        )) { message in
            Alert(title: Text("School selection"), message: Text(message.value), dismissButton: .default(Text("OK")))
        }
    }

    private func updateSchool() async {
        guard let uid = appState.currentUser?.id else { return }
        isUpdating = true
        do {
            let profile = try await AuthService.shared.updateSchool(for: uid, schoolId: selectedSchool.id)
            await MainActor.run {
                appState.currentUser = profile
                appState.selectedSchool = selectedSchool
                appState.sessionPhase = .active
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isUpdating = false
    }
}
