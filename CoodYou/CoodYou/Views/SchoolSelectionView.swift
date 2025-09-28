import SwiftUI

struct SchoolSelectionView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var schoolService = SchoolService.shared
    @State private var errorMessage: String?
    @State private var isUpdating = false
    @State private var selectedSchool: School?
    
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
    @State private var selectedSchool: School = SchoolDirectory.columbia

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("Choose your campus")
                    .font(.largeTitle.weight(.bold))
                Text("CampusDash is piloting at Columbia and Barnard. Pick your school to unlock dining halls, geofences, and notifications.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)
            }
            Spacer()
            if selectedSchool?.id == school.id {
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
        Group {
            if schoolService.schools.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading participating schools...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(schoolService.schools, id: \.id) { school in
                        schoolRow(for: school)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
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
        .disabled(isUpdating || selectedSchool == nil)
    }
            .padding(.top, 60)

            List {
                ForEach(SchoolDirectory.all, id: \.id) { school in
                    HStack {
                        Image(systemName: school.campusIconName)
                            .frame(width: 32)
                            .foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(school.name)
                                .font(.headline)
                            Text(school.allowedEmailDomains.map { "@\($0)" }.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if selectedSchool.id == school.id {
                            Image(systemName: "checkmark")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedSchool = school
                    }
                }
            }
            .listStyle(.insetGrouped)

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
            Spacer()
        }
        .navigationBarHidden(true)
        .task {
            try? await SchoolService.shared.ensureSchoolsLoaded()
            if let existing = appState.selectedSchool {
                selectedSchool = existing
            } else if selectedSchool == nil {
                selectedSchool = schoolService.schools.first
            }
        }
        .onChange(of: schoolService.schools) { schools in
            if selectedSchool == nil {
                selectedSchool = schools.first
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
        guard let uid = appState.currentUser?.id, let selectedSchool else { return }
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
