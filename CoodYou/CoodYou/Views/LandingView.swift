import SwiftUI

struct LandingView: View {
    var body: some View {
        AuthShellView()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
    }
}

struct LandingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            LandingView()
                .environment(\.theme, .current)
                .environmentObject(AppState())
        }
    }
}
