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
        GeometryReader { geometry in
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color.black,
                        Color.black.opacity(0.95),
                        Color.blue.opacity(0.1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Top spacer
                        Spacer()
                            .frame(height: geometry.safeAreaInsets.top + 40)
                        
                        // Header
                        headerSection
                        
                        Spacer()
                            .frame(height: 40)
                        
                        // Form
                        formSection
                        
                        Spacer()
                            .frame(height: 32)
                        
                        // Actions
                        actionSection
                        
                        Spacer()
                            .frame(height: 24)
                        
                        // Footer
                        footerSection
                        
                        // Bottom spacer
                        Spacer()
                            .frame(height: geometry.safeAreaInsets.bottom + 40)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .alert(item: Binding(
            get: { errorMessage.map(ErrorMessage.init(value:)) },
            set: { errorMessage = $0?.value }
        )) { message in
            Alert(title: Text("Sign up"), message: Text(message.value), dismissButton: .default(Text("OK")))
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Back button
            HStack {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.white)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            
            // Title
            VStack(spacing: 12) {
                Text("Join CampusDash")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Create your account to get started")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var formSection: some View {
        VStack(spacing: 24) {
            // Name fields
            HStack(spacing: 16) {
                UberTextField(
                    title: "First Name",
                    placeholder: "First name",
                    text: $firstName,
                    textContentType: .givenName
                )
                
                UberTextField(
                    title: "Last Name",
                    placeholder: "Last name",
                    text: $lastName,
                    textContentType: .familyName
                )
            }
            
            // Email field
            UberTextField(
                title: "Campus Email",
                placeholder: "UNI@columbia.edu",
                text: $email,
                keyboardType: .emailAddress,
                textContentType: .emailAddress,
                autocapitalization: .never,
                disableAutocorrection: true
            )
            
            // Password field
            UberTextField(
                title: "Password",
                placeholder: "Create a password (8+ characters)",
                text: $password,
                isSecure: true,
                textContentType: .newPassword
            )
            
            // Phone field
            UberTextField(
                title: "Phone Number",
                placeholder: "Optional phone number",
                text: $phoneNumber,
                keyboardType: .phonePad,
                textContentType: .telephoneNumber
            )
            
            // School picker
            schoolPickerSection
        }
        .padding(.horizontal, 24)
    }
    
    private var schoolPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("School")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
            }
            
            Menu {
                ForEach(SchoolDirectory.all) { school in
                    Button {
                        selectedSchool = school
                    } label: {
                        VStack(alignment: .leading) {
                            Text(school.name)
                                .font(.body.weight(.semibold))
                            Text(school.allowedEmailDomains.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedSchool.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text(selectedSchool.allowedEmailDomains.joined(separator: ", "))
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    private var actionSection: some View {
        UberButton(
            title: "Create account",
            isLoading: isLoading,
            isDisabled: !formIsValid || isLoading
        ) {
            Task { await register() }
        }
        .padding(.horizontal, 24)
    }
    
    private var footerSection: some View {
        Text("Only @columbia.edu or @barnard.edu addresses are accepted during the pilot.")
            .font(.system(size: 14, weight: .regular))
            .foregroundColor(.white.opacity(0.6))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
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
