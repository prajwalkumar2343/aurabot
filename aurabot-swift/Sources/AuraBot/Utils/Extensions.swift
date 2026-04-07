import Foundation
import SwiftUI

extension Date {
    func formattedRelative() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
    }
}

extension Color {
    static let auraPurple = Color(red: 0.545, green: 0.361, blue: 0.965)
    static let auraYellow = Color(red: 0.961, green: 0.843, blue: 0.435)
}
