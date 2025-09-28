import SwiftUI
import Testing
@testable import CoodYou

@MainActor
struct AuthShellViewModelTests {

    @Test func submittingValidEmailAdvancesToCodeEntry() async throws {
        let service = MockAuthFlowService()
        let viewModel = AuthShellViewModel(service: service)
        viewModel.email = "lion@columbia.edu"
        viewModel.prefersPasswordSignIn = false

        viewModel.handlePrimaryAction()

        try? await Task.sleep(nanoseconds: 600_000_000)

        #expect(viewModel.state == .codeEntry)
        #expect(viewModel.inlineError == nil)
    }

    @Test func invalidEmailShowsInlineError() async {
        let viewModel = AuthShellViewModel(service: MockAuthFlowService())
        viewModel.email = "invalid"
        viewModel.prefersPasswordSignIn = false

        viewModel.handlePrimaryAction()

        #expect(viewModel.inlineError == NSLocalizedString("auth.validation.email", comment: "Invalid email format"))
    }

    @Test func pasteCodeExtractsDigits() async {
        let viewModel = AuthShellViewModel(service: MockAuthFlowService())
        viewModel.pasteIntoCode("Your code is 987654")
        #expect(viewModel.codeDigits.joined() == "987654")
    }

    @Test func passwordStrengthScoring() async {
        let viewModel = AuthShellViewModel(service: MockAuthFlowService())
        #expect(viewModel.passwordStrength("abc").rawValue == "weak")
        #expect(viewModel.passwordStrength("Abc12345").rawValue == "medium")
        #expect(viewModel.passwordStrength("StrongPass123!").rawValue == "strong")
    }
}
