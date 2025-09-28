import SwiftUI

// MARK: - Uber-Style TextField Component
struct UberTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .sentences
    var disableAutocorrection: Bool = false
    
    @FocusState private var isFocused: Bool
    @State private var isAnimated = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Floating label
            HStack {
                Text(title)
                    .font(.system(size: isFocused || !text.isEmpty ? 14 : 16, weight: .medium))
                    .foregroundColor(isFocused ? .accentColor : .secondary)
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
                    .animation(.easeInOut(duration: 0.2), value: text.isEmpty)
                
                Spacer()
            }
            
            // Input field
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                isFocused ? Color.accentColor : Color.clear,
                                lineWidth: 2
                            )
                    )
                    .frame(height: 56)
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
                
                // Input
                HStack {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                            .textContentType(textContentType)
                            .focused($isFocused)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    } else {
                        TextField(placeholder, text: $text)
                            .keyboardType(keyboardType)
                            .textContentType(textContentType)
                            .textInputAutocapitalization(autocapitalization)
                            .disableAutocorrection(disableAutocorrection)
                            .focused($isFocused)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    
                    // Clear button
                    if !text.isEmpty && isFocused {
                        Button {
                            text = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 16))
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: text.isEmpty)
    }
}

// MARK: - Uber-Style Picker Field
struct UberPickerField<SelectionValue: Hashable, Content: View>: View {
    let title: String
    @Binding var selection: SelectionValue
    @ViewBuilder let content: Content
    
    @State private var showingPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Label
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            // Picker button
            Button {
                showingPicker = true
            } label: {
                HStack {
                    Text(getSelectionText())
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.systemGray6))
                )
            }
            .sheet(isPresented: $showingPicker) {
                NavigationView {
                    List {
                        Picker("Select", selection: $selection) {
                            content
                        }
                        .pickerStyle(.wheel)
                    }
                    .navigationTitle(title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingPicker = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }
    
    private func getSelectionText() -> String {
        // This is a simplified version - in a real implementation,
        // you'd want to extract the display text from the selection
        return "\(selection)"
    }
}

// MARK: - Uber-Style Button
struct UberButton: View {
    let title: String
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isDisabled ? Color.gray : Color.accentColor)
            )
            .scaleEffect(isDisabled ? 1.0 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isDisabled)
        }
        .disabled(isDisabled)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 24) {
        UberTextField(
            title: "Email",
            placeholder: "Enter your email",
            text: .constant(""),
            keyboardType: .emailAddress
        )
        
        UberTextField(
            title: "Password",
            placeholder: "Enter your password",
            text: .constant(""),
            isSecure: true
        )
        
        UberButton(
            title: "Sign In",
            isLoading: false,
            isDisabled: false
        ) {
            // Action
        }
    }
    .padding(24)
}
