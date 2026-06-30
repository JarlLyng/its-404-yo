import SwiftUI
import UniformTypeIdentifiers
import IAMJARLDesignTokens

/// The empty-state drop target shown before any files are added.
struct DropZoneView: View {
    let isAnalyzing: Bool
    let onDrop: ([URL]) -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: isAnalyzing ? "waveform.circle" : "square.and.arrow.down.on.square")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(DesignTokens.Common.primary(scheme))
                .opacity(isAnalyzing ? 0.6 : 1)
                .accessibilityHidden(true)

            Text(isAnalyzing ? "Analyzing…" : "Drop your sample pack here")
                .font(.system(size: DesignTokens.Typography.Size.xl, weight: DesignTokens.Typography.Weight.semibold))
                .foregroundStyle(DesignTokens.Common.Text.primary(scheme))

            Text("Folders or files · WAV, AIFF, MP3, M4A, AAC, FLAC")
                .font(.system(size: DesignTokens.Typography.Size.sm))
                .foregroundStyle(DesignTokens.Common.Text.secondary(scheme))

            Button("Choose files…") { chooseFiles() }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignTokens.Spacing.xxxl)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                .strokeBorder(
                    isTargeted ? DesignTokens.Common.primary(scheme) : DesignTokens.Common.Border.subtle(scheme),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                )
                .background(
                    isTargeted ? DesignTokens.Common.primarySubtle(scheme) : Color.clear,
                    in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                )
        )
        .padding(DesignTokens.Spacing.xxl)
        .dropDestination(for: URL.self) { urls, _ in
            onDrop(urls)
            return true
        } isTargeted: { targeted in
            withAnimation(reduceMotion ? nil : DesignTokens.Motion.Easing.standard()) { isTargeted = targeted }
        }
    }

    private func chooseFiles() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            onDrop(panel.urls)
        }
    }
}
