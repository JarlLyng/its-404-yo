import SwiftUI
import UniformTypeIdentifiers
import IAMJARLDesignTokens

struct ContentView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            if state.items.isEmpty {
                DropZoneView(isAnalyzing: state.isAnalyzing) { urls in
                    state.handleDrop(urls: urls)
                }
            } else {
                FileListView()
                Divider()
                ActionBar()
            }
        }
        .background(DesignTokens.Common.Background.app(scheme))
        .animation(DesignTokens.Motion.Easing.standard(), value: state.items.isEmpty)
    }
}

/// Bottom toolbar: target rate, output folder, and the convert button + progress / report.
private struct ActionBar: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            if let report = state.lastReport {
                ReportView(report: report)
            }

            if state.isConverting {
                ProgressView(value: state.progress) {
                    Text("Converting… \(Int(state.progress * 100))%")
                        .font(.system(size: DesignTokens.Typography.Size.sm))
                }
                .tint(DesignTokens.Common.primary(scheme))
            }

            HStack(spacing: DesignTokens.Spacing.md) {
                Button {
                    state.reset()
                } label: {
                    Label("Clear", systemImage: "xmark.circle")
                }

                Picker("Sample rate", selection: $state.settings.targetSampleRate) {
                    ForEach(ConversionSettings.TargetSampleRate.allCases) { rate in
                        Text(rate.label).tag(rate)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 220)

                OutputFolderButton()

                Spacer()

                Button {
                    state.convert()
                } label: {
                    Label("Make SP-404 Ready", systemImage: "checkmark.seal.fill")
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignTokens.Common.primary(scheme))
                .disabled(!state.canConvert)
            }
        }
        .padding(DesignTokens.Spacing.lg)
    }
}

private struct OutputFolderButton: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Button {
            chooseOutputFolder()
        } label: {
            if let dir = state.outputDirectory {
                Label(dir.lastPathComponent, systemImage: "folder.fill")
                    .lineLimit(1)
            } else {
                Label("Choose output folder…", systemImage: "folder.badge.plus")
            }
        }
    }

    private func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.message = "Choose where to save the SP-404-ready files"
        if panel.runModal() == .OK {
            state.outputDirectory = panel.url
        }
    }
}

private struct ReportView: View {
    let report: ConversionReport
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: report.failed == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(report.failed == 0
                    ? DesignTokens.Common.State.success(scheme)
                    : DesignTokens.Common.State.warning(scheme))
            Text("\(report.converted) converted · \(report.copied) already OK · \(report.failed) failed")
                .font(.system(size: DesignTokens.Typography.Size.sm))
            Spacer()
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([report.outputDirectory])
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Common.Background.card(scheme))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
    }
}
