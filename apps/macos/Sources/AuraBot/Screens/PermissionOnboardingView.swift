import SwiftUI
import AppKit
import AVFoundation
import CoreGraphics

enum AppPermissionKind: String, CaseIterable, Identifiable, Hashable {
    case screenRecording
    case accessibility
    case microphone

    var id: String { rawValue }

    var title: String {
        switch self {
        case .screenRecording:
            return "Screen Recording"
        case .accessibility:
            return "Accessibility"
        case .microphone:
            return "Microphone"
        }
    }

    var description: String {
        switch self {
        case .screenRecording:
            return "Lets Aura understand what is on screen and capture meaningful context."
        case .accessibility:
            return "Lets Aura observe app changes, shortcuts, and richer desktop state."
        case .microphone:
            return "Optional voice input for chat and future hands-free controls."
        }
    }

    var icon: String {
        switch self {
        case .screenRecording:
            return "record.circle"
        case .accessibility:
            return "figure.wave"
        case .microphone:
            return "mic"
        }
    }

    var settingsAnchor: String {
        switch self {
        case .screenRecording:
            return "Privacy_ScreenCapture"
        case .accessibility:
            return "Privacy_Accessibility"
        case .microphone:
            return "Privacy_Microphone"
        }
    }

    var actionTitle: String {
        switch self {
        case .screenRecording:
            return "Open Screen Recording"
        case .accessibility:
            return "Open Accessibility"
        case .microphone:
            return "Open Microphone"
        }
    }

    var badgeTitle: String {
        isRequired ? "Required" : "Optional"
    }

    var isRequired: Bool {
        switch self {
        case .screenRecording, .accessibility:
            return true
        case .microphone:
            return false
        }
    }

    @available(macOS 14.0, *)
    var accentColor: Color {
        switch self {
        case .screenRecording:
            return Colors.primary
        case .accessibility:
            return Colors.secondary
        case .microphone:
            return Colors.accent
        }
    }
}

struct AppPermissionStatus: Identifiable, Equatable {
    let kind: AppPermissionKind
    let state: AppPermissionState

    var id: AppPermissionKind { kind }
    var isGranted: Bool { state == .granted }
}

enum AppPermissionState: Equatable {
    case granted
    case pendingRestart
    case notGranted

    var title: String {
        switch self {
        case .granted:
            return "Enabled"
        case .pendingRestart:
            return "Restart Aura"
        case .notGranted:
            return "Open Panel"
        }
    }

    var symbolName: String {
        switch self {
        case .granted:
            return "checkmark.circle.fill"
        case .pendingRestart:
            return "arrow.clockwise.circle.fill"
        case .notGranted:
            return "arrow.up.right"
        }
    }

    var tintColor: Color {
        switch self {
        case .granted:
            return Colors.success
        case .pendingRestart:
            return Colors.warning
        case .notGranted:
            return Colors.primary
        }
    }
}

@MainActor
enum PermissionCenter {
    private static var requestedKinds = Set<AppPermissionKind>()

    static func allStatuses() -> [AppPermissionStatus] {
        AppPermissionKind.allCases.map(status(for:))
    }

    static func status(for kind: AppPermissionKind) -> AppPermissionStatus {
        AppPermissionStatus(kind: kind, state: state(for: kind))
    }

    static func state(for kind: AppPermissionKind) -> AppPermissionState {
        switch kind {
        case .screenRecording:
            if CGPreflightScreenCaptureAccess() {
                requestedKinds.remove(kind)
                return .granted
            }

            return requestedKinds.contains(kind) ? .pendingRestart : .notGranted
        case .accessibility:
            return isGranted(kind) ? .granted : .notGranted
        case .microphone:
            return isGranted(kind) ? .granted : .notGranted
        }
    }

    static func isGranted(_ kind: AppPermissionKind) -> Bool {
        switch kind {
        case .screenRecording:
            return CGPreflightScreenCaptureAccess()
        case .accessibility:
            return SystemAccessibilityPermissionChecker().isTrusted(prompt: false)
        case .microphone:
            return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        }
    }

    static func requestAccess(for kind: AppPermissionKind) {
        switch kind {
        case .screenRecording:
            requestedKinds.insert(kind)
            _ = CGRequestScreenCaptureAccess()
            openSystemSettings(for: kind)
        case .accessibility:
            let trusted = SystemAccessibilityPermissionChecker().isTrusted(prompt: true)
            if trusted {
                requestedKinds.remove(kind)
            } else {
                openSystemSettings(for: kind)
            }
        case .microphone:
            AVCaptureDevice.requestAccess(for: .audio) { _ in }
        }
    }

    @MainActor
    static func openSystemSettings(for kind: AppPermissionKind) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(kind.settingsAnchor)") else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}

@available(macOS 14.0, *)
struct PermissionOnboardingView: View {
    @ObservedObject var service: AppService
    @State private var appear = false

    private var requiredStatuses: [AppPermissionStatus] {
        service.permissionStatuses.filter { $0.kind.isRequired }
    }

    private var completedRequiredCount: Int {
        requiredStatuses.filter { $0.isGranted }.count
    }

    private var progressValue: Double {
        guard !requiredStatuses.isEmpty else { return 1 }
        return Double(completedRequiredCount) / Double(requiredStatuses.count)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.xxxl) {
                HStack(alignment: .top, spacing: Spacing.xxxxl) {
                    VStack(alignment: .leading, spacing: Spacing.xl) {
                        permissionEyebrow

                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("Finish setup before Aura starts observing your workspace.")
                                .font(Typography.largeTitle)
                                .foregroundColor(Colors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("Enable the required macOS permissions below. Each checklist item jumps straight into the matching system privacy panel.")
                                .font(Typography.body)
                                .foregroundColor(Colors.textSecondary)
                                .frame(maxWidth: 540, alignment: .leading)
                        }

                        HStack(spacing: Spacing.md) {
                            GradientButton("Refresh Status", icon: "arrow.clockwise") {
                                service.refreshPermissionStatuses()
                            }

                            SecondaryButton("Open Settings", icon: "gearshape") {
                                service.openSystemSettings(for: .screenRecording)
                            }
                        }

                        Text(service.permissionGuidanceMessage ?? "Aura unlocks once Screen Recording and Accessibility are enabled.")
                            .font(Typography.caption)
                            .foregroundColor(Colors.textMuted)
                    }

                    Spacer(minLength: 0)

                    PermissionProgressCard(
                        completedCount: completedRequiredCount,
                        totalCount: requiredStatuses.count,
                        progressValue: progressValue
                    )
                    .frame(width: 240)
                }

                GlassCard(padding: Spacing.xxl, cornerRadius: 28, shadow: Shadows.xl, showBorder: true) {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        HStack {
                            Text("Permission Checklist")
                                .font(Typography.title2)
                                .foregroundColor(Colors.textPrimary)

                            Spacer()

                            Text("\(completedRequiredCount)/\(requiredStatuses.count) required")
                                .font(Typography.caption)
                                .foregroundColor(Colors.primary)
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, Spacing.xs)
                                .background(Colors.primaryMuted)
                                .cornerRadius(Radius.full)
                        }

                        ForEach(Array(service.permissionStatuses.enumerated()), id: \.element.id) { index, status in
                            PermissionChecklistRow(
                                status: status,
                                onTap: { service.requestPermission(status.kind) }
                            )
                            .opacity(appear ? 1 : 0)
                            .offset(y: appear ? 0 : 12)
                            .animation(
                                AnimationPresets.spring.delay(0.08 + Double(index) * 0.05),
                                value: appear
                            )
                        }
                    }
                }

                BrowserExtensionSetupCard(service: service)

                HStack(spacing: Spacing.md) {
                    Image(systemName: "sparkles")
                        .foregroundColor(Colors.primary)

                    Text("The checklist stays available in Settings after onboarding, so you can revisit permissions later.")
                        .font(Typography.callout)
                        .foregroundColor(Colors.textSecondary)
                }
                .padding(.horizontal, Spacing.sm)
            }
            .padding(Spacing.xxxxl)
        }
        .background(onboardingBackground)
        .onAppear {
            service.refreshPermissionStatuses()
            withAnimation(AnimationPresets.appear) {
                appear = true
            }
        }
    }

    private var permissionEyebrow: some View {
        HStack(spacing: Spacing.sm) {
            Circle()
                .fill(Colors.primary)
                .frame(width: 8, height: 8)

            Text("Onboarding")
                .font(Typography.caption)
                .foregroundColor(Colors.textSecondary)

            Text("Privacy setup")
                .font(Typography.caption)
                .foregroundColor(Colors.primary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            Capsule()
                .fill(Colors.surface)
                .overlay(
                    Capsule()
                        .stroke(Colors.border, lineWidth: 1)
                )
        )
    }

    private var onboardingBackground: some View {
        ZStack {
            Colors.background

            LinearGradient(
                colors: [
                    Colors.primary.opacity(0.12),
                    Colors.secondary.opacity(0.08),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Colors.primary.opacity(0.10))
                .frame(width: 380, height: 380)
                .blur(radius: 60)
                .offset(x: -260, y: -180)

            Circle()
                .fill(Colors.secondary.opacity(0.09))
                .frame(width: 300, height: 300)
                .blur(radius: 50)
                .offset(x: 320, y: -140)
        }
    }
}

@available(macOS 14.0, *)
struct BrowserExtensionSetupCard: View {
    @ObservedObject var service: AppService

    var body: some View {
        GlassCard(padding: Spacing.xxl, cornerRadius: 28, shadow: Shadows.lg, showBorder: true) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Chrome Extension")
                            .font(Typography.title2)
                            .foregroundColor(Colors.textPrimary)

                        Text("Optional, but recommended for richer browser context and page awareness inside Chrome.")
                            .font(Typography.callout)
                            .foregroundColor(Colors.textSecondary)
                    }

                    Spacer()

                    Text(service.browserExtensionConfigured ? "Configured" : "Recommended")
                        .font(Typography.caption)
                        .foregroundColor(service.browserExtensionConfigured ? Colors.success : Colors.accent)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(
                            Capsule()
                                .fill(service.browserExtensionConfigured ? Colors.success.opacity(0.12) : Colors.accent.opacity(0.12))
                        )
                }

                Button {
                    service.installChromeExtension()
                } label: {
                    HStack(spacing: Spacing.lg) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Colors.accent.opacity(0.12))
                                .frame(width: 52, height: 52)

                            Image(systemName: "puzzlepiece.extension")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(Colors.accent)
                        }

                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            HStack(spacing: Spacing.sm) {
                                Text("Install Aura In Chrome")
                                    .font(Typography.headline)
                                    .foregroundColor(Colors.textPrimary)

                                Text("Optional")
                                    .font(Typography.caption2)
                                    .foregroundColor(Colors.textSecondary)
                                    .padding(.horizontal, Spacing.sm)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule()
                                            .fill(Colors.surfaceTertiary)
                                    )
                            }

                            Text("Launches Chrome with the Aura extension loaded so the browser context bridge is ready immediately.")
                                .font(Typography.callout)
                                .foregroundColor(Colors.textSecondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: Spacing.xs) {
                            Text(service.hasChromeExtensionBundle ? "Open Chrome" : "Open Setup")
                                .font(Typography.caption)
                                .foregroundColor(Colors.accent)

                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Colors.accent)
                        }
                    }
                    .padding(Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(Colors.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 22)
                                    .stroke(Colors.border, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: Spacing.md) {
                    BrowserExtensionStep(
                        index: "1",
                        title: "Install flow",
                        detail: service.hasChromeExtensionBundle ? "Aura opens Chrome and loads the bundled extension automatically." : "Aura opens Chrome setup so you can finish loading the extension manually."
                    )
                    BrowserExtensionStep(
                        index: "2",
                        title: "API key",
                        detail: service.browserExtensionConfigured ? "Use the Browser Extension API key from Settings." : "Add an API key in Settings first, then paste it into the extension options."
                    )
                    BrowserExtensionStep(
                        index: "3",
                        title: "Local server URL",
                        detail: service.browserExtensionServerURL,
                        isMono: true
                    )
                }
            }
        }
    }
}

@available(macOS 14.0, *)
struct BrowserExtensionStep: View {
    let index: String
    let title: String
    let detail: String
    var isMono: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Text(index)
                .font(Typography.caption.weight(.semibold))
                .foregroundColor(Colors.textInverse)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Colors.accent))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.subheadline.weight(.semibold))
                    .foregroundColor(Colors.textPrimary)

                Text(detail)
                    .font(isMono ? Typography.mono : Typography.callout)
                    .foregroundColor(Colors.textSecondary)
                    .textSelection(.enabled)
            }
        }
    }
}

@available(macOS 14.0, *)
struct PermissionProgressCard: View {
    let completedCount: Int
    let totalCount: Int
    let progressValue: Double

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .stroke(Colors.border, lineWidth: 14)

                Circle()
                    .trim(from: 0, to: max(0.02, progressValue))
                    .stroke(
                        AngularGradient(
                            colors: [Colors.primary, Colors.secondary, Colors.primary],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: Spacing.xs) {
                    Text("\(completedCount)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(Colors.textPrimary)

                    Text("of \(totalCount)")
                        .font(Typography.caption)
                        .foregroundColor(Colors.textSecondary)
                }
            }
            .frame(width: 132, height: 132)

            Text("Required Access")
                .font(Typography.headline)
                .foregroundColor(Colors.textPrimary)

            Text(completedCount == totalCount ? "Aura is ready to start." : "Grant the remaining items to continue.")
                .font(Typography.callout)
                .foregroundColor(Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.xxl)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Colors.surface.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Colors.border, lineWidth: 1)
                )
        )
        .shadow(color: Shadows.lg.color, radius: Shadows.lg.radius, x: Shadows.lg.x, y: Shadows.lg.y)
    }
}

@available(macOS 14.0, *)
struct PermissionChecklistGroup: View {
    let statuses: [AppPermissionStatus]
    let onTap: (AppPermissionKind) -> Void

    var body: some View {
        VStack(spacing: Spacing.md) {
            ForEach(statuses) { status in
                PermissionChecklistRow(status: status) {
                    onTap(status.kind)
                }
            }
        }
    }
}

@available(macOS 14.0, *)
struct PermissionChecklistRow: View {
    let status: AppPermissionStatus
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.lg) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(statusIconColor.opacity(status.state == .granted ? 0.18 : 0.10))
                        .frame(width: 52, height: 52)

                    Image(systemName: status.state == .notGranted ? status.kind.icon : status.state.symbolName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(statusIconColor)
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.sm) {
                        Text(status.kind.title)
                            .font(Typography.headline)
                            .foregroundColor(Colors.textPrimary)

                        Text(status.kind.badgeTitle)
                            .font(Typography.caption2)
                            .foregroundColor(status.kind.isRequired ? Colors.primary : Colors.textSecondary)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(status.kind.isRequired ? Colors.primaryMuted : Colors.surfaceTertiary)
                            )
                    }

                    Text(status.kind.description)
                        .font(Typography.callout)
                        .foregroundColor(Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: Spacing.xs) {
                    Text(status.state.title)
                        .font(Typography.caption)
                        .foregroundColor(status.state.tintColor)

                    Image(systemName: trailingSymbolName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(status.state.tintColor)
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(isHovered ? Colors.surfaceSecondary : Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(borderColor, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(AnimationPresets.hover, value: isHovered)
        .onHover { isHovered = $0 }
    }

    private var statusIconColor: Color {
        switch status.state {
        case .granted:
            return Colors.success
        case .pendingRestart:
            return Colors.warning
        case .notGranted:
            return status.kind.accentColor
        }
    }

    private var trailingSymbolName: String {
        switch status.state {
        case .granted:
            return "checkmark"
        case .pendingRestart:
            return "arrow.clockwise"
        case .notGranted:
            return "arrow.up.right"
        }
    }

    private var borderColor: Color {
        switch status.state {
        case .granted:
            return Colors.success.opacity(0.28)
        case .pendingRestart:
            return Colors.warning.opacity(0.28)
        case .notGranted:
            return isHovered ? Colors.borderHover : Colors.border
        }
    }
}
