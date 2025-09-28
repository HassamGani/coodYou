import SwiftUI
import Testing
@testable import CoodYou

@MainActor
struct AuthShellSnapshotTests {

    @Test func renderWelcomeLightProducesImage() async throws {
        let view = AuthShellView(service: MockAuthFlowService())
            .environment(\.theme, .current)
            .frame(width: 390, height: 844)
            .environmentObject(AppState())

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = renderer.uiImage

        #expect(image != nil)
        #expect(image?.size.width == 390)
    }
}
