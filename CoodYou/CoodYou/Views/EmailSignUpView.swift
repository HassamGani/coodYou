import SwiftUI

struct EmailSignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var phoneNumber = ""
    @State private var selectedSchool: School = SchoolDirectory.columbia
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Name") {
                TextField("First name", text: $firstName)
                    .textContentType(.givenName)
                TextField("Last name", text: $lastName)
                    .textContentType(.familyName)
            }

            Section("Campus email") {
                TextField("UNI@columbia.edu", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                SecureField("Password", text: $password)
                    .textContentType(.newPassword)
            }

            Section("Contact") {
                TextField("Optional phone", text: $phoneNumber)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
            }

            Section("School") {
                Picker("Select", selection: $selectedSchool) {
                    ForEach(SchoolDirectory.all) { school in
                        VStack(alignment: .leading) {
                            Text(school.name)
                                .font(.body.weight(.semibold))
                            Text(school.allowedEmailDomains.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(school)
                    }
                }
            }

            Section {
                Button {
                    Task { await register() }
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Create account")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(!formIsValid || isLoading)
            }
            footer:
            {
                Text("Only @columbia.edu or @barnard.edu addresses are accepted during the pilot.")
                    .font(.footnote)
            }
        }
        .navigationTitle("Create account")
        .alert(item: Binding(
            get: { errorMessage.map(ErrorMessage.init(value:)) },
            set: { errorMessage = $0?.value }
        )) { message in
            Alert(title: Text("Sign up"), message: Text(message.value), dismissButton: .default(Text("OK")))
        }
    }

    private var formIsValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty && !email.isEmpty && password.count >= 8
    }

    private func register() async {
        guard formIsValid else { return }
        isLoading = true
        do {
            _ = try await AuthService.shared.register(
                firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                email: email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
                school: selectedSchool
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
