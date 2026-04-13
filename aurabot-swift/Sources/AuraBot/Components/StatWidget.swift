import SwiftUI

@available(macOS 14.0, *)
struct StatWidget: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let trend: String?
    
    @State private var isHovered = false
    @State private var tiltX: Double = 0
    @State private var tiltY: Double = 0
    
    init(
        title: String,
        value: String,
        icon: String,
        color: Color = Colors.primary,
        trend: String? = nil
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.trend = trend
    }
    
    var body: some View {
        GlassCard(padding: Spacing.xl, shadow: isHovered ? Shadows.lg : Shadows.md) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Icon
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(color)
                }
                
                // Value and Title
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(value)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(Colors.textPrimary)
                    
                    HStack(spacing: Spacing.xs) {
                        Text(title)
                            .font(Typography.subheadline)
                            .foregroundColor(Colors.textSecondary)
                        
                        if let trend = trend {
                            Text(trend)
                                .font(Typography.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(Colors.success)
                                .padding(.horizontal, Spacing.xs)
                                .padding(.vertical, 2)
                                .background(Colors.success.opacity(0.1))
                                .cornerRadius(Radius.sm)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .rotation3DEffect(
            .degrees(tiltX),
            axis: (x: 0, y: 1, z: 0)
        )
        .rotation3DEffect(
            .degrees(tiltY),
            axis: (x: 1, y: 0, z: 0)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .offset(y: isHovered ? -4 : 0)
        .animation(AnimationPresets.hover, value: isHovered)
        .animation(AnimationPresets.hover, value: tiltX)
        .animation(AnimationPresets.hover, value: tiltY)
        .onHover { hovering in
            isHovered = hovering
            if !hovering {
                tiltX = 0
                tiltY = 0
            }
        }
    }
}

@available(macOS 14.0, *)
struct AnimatedStatWidget: View {
    let title: String
    let value: Int
    let icon: String
    let color: Color
    
    @State private var displayValue: Int = 0
    @State private var isHovered = false
    
    var body: some View {
        GlassCard(padding: Spacing.xl, shadow: isHovered ? Shadows.lg : Shadows.md) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Icon with glow
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 48, height: 48)
                        .shadow(color: isHovered ? color.opacity(0.3) : Color.clear, radius: 20)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(color)
                }
                
                // Animated Value
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("\(displayValue)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(Colors.textPrimary)
                    
                    Text(title)
                        .font(Typography.subheadline)
                        .foregroundColor(Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .offset(y: isHovered ? -4 : 0)
        .animation(AnimationPresets.hover, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            animateValue()
        }
        .onChange(of: value) { _ in
            animateValue()
        }
    }
    
    private func animateValue() {
        let steps = 30
        let duration = 1.0
        let stepDuration = duration / Double(steps)
        let increment = Double(value) / Double(steps)
        
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + (Double(i) * stepDuration)) {
                withAnimation(.linear(duration: stepDuration)) {
                    displayValue = min(Int(Double(i) * increment), value)
                }
            }
        }
    }
}

@available(macOS 14.0, *)
struct MiniStatWidget: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(color.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(Colors.textPrimary)
                
                Text(label)
                    .font(Typography.caption)
                    .foregroundColor(Colors.textSecondary)
            }
            
            Spacer()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(isHovered ? Colors.surfaceHover : Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .stroke(Colors.border, lineWidth: 1)
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(AnimationPresets.hover, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

@available(macOS 14.0, *)
struct StatWidget_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: Spacing.lg) {
            StatWidget(
                title: "Total Memories",
                value: "1,234",
                icon: "brain.head.profile",
                color: Colors.primary,
                trend: "+12%"
            )
            
            AnimatedStatWidget(
                title: "Captures Today",
                value: 156,
                icon: "camera.fill",
                color: Colors.success
            )
            
            MiniStatWidget(
                value: "99.9%",
                label: "Uptime",
                icon: "checkmark.shield.fill",
                color: Colors.accent
            )
        }
        .padding()
        .background(Colors.background)
    }
}
