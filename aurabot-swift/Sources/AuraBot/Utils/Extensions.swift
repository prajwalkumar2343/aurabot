import Foundation
import SwiftUI

// MARK: - Date Extensions
extension Date {
    func formattedRelative() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    func formattedCompact() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}

// MARK: - View Extensions
@available(macOS 14.0, *)
extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
    }
    
    func glassmorphic() -> some View {
        self
            .background(.ultraThinMaterial)
            .background(Colors.white.opacity(0.7))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Colors.border, lineWidth: 1)
            )
            .cornerRadius(16)
            .shadow(color: Shadows.md.color, radius: Shadows.md.radius, x: Shadows.md.x, y: Shadows.md.y)
    }
    
    func withPageTransition() -> some View {
        self.transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .trailing)),
            removal: .opacity.combined(with: .move(edge: .leading))
        ))
    }
}

// MARK: - Color Extensions
@available(macOS 14.0, *)
extension Color {
    static let auraPurple = Color(hex: "#6366F1")
    static let auraYellow = Color(hex: "#F59E0B")
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Animation Extensions
@available(macOS 14.0, *)
extension Animation {
    static func smooth(duration: Double = 0.3) -> Animation {
        .easeInOut(duration: duration)
    }
    
    static func bouncy(duration: Double = 0.5) -> Animation {
        .spring(response: duration, dampingFraction: 0.7)
    }
    
    static func snappy(duration: Double = 0.3) -> Animation {
        .spring(response: duration, dampingFraction: 0.9)
    }
}

// MARK: - String Extensions
extension String {
    func truncated(to length: Int, trailing: String = "...") -> String {
        if self.count > length {
            return String(self.prefix(length)) + trailing
        }
        return self
    }
}

// MARK: - CGFloat Extensions
extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
