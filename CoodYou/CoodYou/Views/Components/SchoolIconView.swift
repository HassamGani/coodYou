import SwiftUI
import UIKit

struct SchoolIconView: View {
    let school: School?
    var size: CGFloat = 28

    private var initials: String {
        let text = school?.displayName ?? school?.name ?? "?"
        return text.isEmpty ? "?" : String(text.prefix(1))
    }

    var body: some View {
        if let icon = school?.iconName, UIImage(systemName: icon) != nil {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundStyle(Color.accentColor)
        } else {
            Circle()
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: size, height: size)
                .overlay {
                    Text(initials.uppercased())
                        .font(.system(size: size * 0.5, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
        }
    }
}
