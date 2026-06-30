import SwiftUI
import IAMJARLDesignTokens

/// The analysis list: every scanned file with its compatibility verdict and reasons.
struct FileListView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summaryHeader
            List(state.items) { item in
                FileRow(item: item)
                    .listRowBackground(Color.clear)
            }
            .listStyle(.inset)
        }
    }

    private var summaryHeader: some View {
        HStack(spacing: DesignTokens.Spacing.lg) {
            Text("\(state.items.count) files")
                .font(.system(size: DesignTokens.Typography.Size.base, weight: DesignTokens.Typography.Weight.semibold))
            Text("\(state.convertCount) to convert")
                .foregroundStyle(DesignTokens.Common.primary(scheme))
            Text("\(state.compatibleCount) already OK")
                .foregroundStyle(DesignTokens.Common.Text.secondary(scheme))
            if state.unreadableCount > 0 {
                Text("\(state.unreadableCount) unreadable")
                    .foregroundStyle(DesignTokens.Common.State.error(scheme))
            }
            Spacer()
        }
        .font(.system(size: DesignTokens.Typography.Size.sm))
        .padding(DesignTokens.Spacing.lg)
    }
}

private struct FileRow: View {
    let item: AudioFileItem
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            statusIcon
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(item.fileName)
                    .font(.system(size: DesignTokens.Typography.Size.sm, weight: DesignTokens.Typography.Weight.semibold))
                    .foregroundStyle(DesignTokens.Common.Text.primary(scheme))
                if let detail = detailLine {
                    Text(detail)
                        .font(.system(size: DesignTokens.Typography.Size.xs))
                        .foregroundStyle(DesignTokens.Common.Text.tertiary(scheme))
                }
            }
            Spacer()
            reasonBadges
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    /// One coherent VoiceOver sentence per row instead of icon/name/badges read separately.
    private var accessibilityDescription: String {
        var parts = [item.fileName]
        switch item.status {
        case .compatible:
            parts.append("already compatible")
        case let .needsConversion(reasons):
            parts.append("needs conversion")
            parts.append(contentsOf: reasons)
        case .unreadable:
            parts.append("unreadable")
        }
        if let detail = detailLine { parts.append(detail) }
        parts.append(contentsOf: item.warnings)
        return parts.joined(separator: ", ")
    }

    @ViewBuilder private var statusIcon: some View {
        switch item.status {
        case .compatible:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(DesignTokens.Common.State.success(scheme))
        case .needsConversion:
            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .foregroundStyle(DesignTokens.Common.primary(scheme))
        case .unreadable:
            Image(systemName: "xmark.octagon.fill")
                .foregroundStyle(DesignTokens.Common.State.error(scheme))
        }
    }

    private var detailLine: String? {
        guard let p = item.properties else { return nil }
        let rate = AudioFormatInspector.formatKHz(p.sampleRate)
        let ch = p.channels == 1 ? "mono" : (p.channels == 2 ? "stereo" : "\(p.channels)ch")
        if p.isMP3 { return "MP3 · \(rate) kHz · \(ch)" }
        let depth = p.isFloat ? "\(p.bitsPerChannel)-bit float" : "\(p.bitsPerChannel)-bit"
        return "\(depth) · \(rate) kHz · \(ch)"
    }

    @ViewBuilder private var reasonBadges: some View {
        VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xs) {
            if case let .needsConversion(reasons) = item.status {
                ForEach(reasons, id: \.self) { reason in
                    Text(reason)
                        .font(.system(size: DesignTokens.Typography.Size.xs))
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(DesignTokens.Common.primarySubtle(scheme))
                        .clipShape(Capsule())
                }
            }
            ForEach(item.warnings, id: \.self) { warning in
                Text(warning)
                    .font(.system(size: DesignTokens.Typography.Size.xs))
                    .foregroundStyle(DesignTokens.Common.State.warning(scheme))
            }
        }
    }
}
