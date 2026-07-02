//
//  SetupWizardView.swift
//  GW2onMac
//

import SwiftUI
import GW2Kit
import UniformTypeIdentifiers

struct SetupWizardView: View {
    @EnvironmentObject private var appState: AppState
    @State private var statusMessage = ""
    @State private var isBusy = false
    @State private var showImportPicker = false
    @State private var showGPTKFilePicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            rosettaStep
            runtimeStep
            gptkStep
            prefixStep
            gameInstallStep

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Refresh") { appState.refresh() }
                    .disabled(isBusy || appState.isRuntimeBusy || appState.isGW2InstallBusy || appState.isGPTKInstallBusy)

                Spacer()

                if appState.isReadyToPlay {
                    Button("Open Launcher") { appState.finishSetupWizard() }
                        .keyboardShortcut(.defaultAction)
                }
            }

            Spacer(minLength: 0)

            Text("Unsupported by ArenaNet. Use at your own risk.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 520)
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let folder = urls.first else { return }
                Task { await appState.importExistingInstall(from: folder) }
            case .failure(let error):
                statusMessage = error.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $showGPTKFilePicker,
            allowedContentTypes: [UTType(filenameExtension: "dmg")!],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let dmg = urls.first else { return }
                Task { await appState.installGPTK(from: dmg) }
            case .failure(let error):
                statusMessage = error.localizedDescription
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("GW2onMac Setup")
                .font(.largeTitle.bold())
            Text("Get Guild Wars 2 running on Apple Silicon")
                .foregroundStyle(.secondary)
        }
    }

    private var rosettaStep: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                stepIcon(ok: appState.isRosettaInstalled)
                Text("Rosetta 2")
                    .font(.headline)
                Spacer()
                if !appState.isRosettaInstalled {
                    Button("Install Rosetta") {
                        Task { await appState.installRosetta() }
                    }
                    .disabled(appState.isRuntimeBusy || appState.isRosettaInstallBusy)
                }
            }

            rosettaInstallProgress

            Text(rosettaDetail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var rosettaInstallProgress: some View {
        switch appState.rosettaInstallPhase {
        case .installing:
            ProgressView("Installing Rosetta 2…")
        case .failed(let message):
            VStack(alignment: .leading, spacing: 4) {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Dismiss") { appState.resetRosettaInstallPhase() }
                    .font(.caption)
            }
        default:
            EmptyView()
        }
    }

    private var rosettaDetail: String {
        if appState.isRosettaInstalled {
            return "Rosetta 2 is installed. GW2onMac’s Wine runtime runs as x86_64 code on Apple Silicon."
        }
        return """
        GW2onMac’s Wine runtime is built for Intel (x86_64) and runs under Rosetta 2 on M-series Macs. \
        Click Install Rosetta, or it will install automatically when you download the runtime or create the prefix.
        """
    }

    private var runtimeStep: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                stepIcon(ok: appState.isRuntimeInstalled)
                Text("Wine runtime")
                    .font(.headline)
                Spacer()
                if !appState.isRuntimeInstalled {
                    Button("Download Runtime") {
                        Task { await appState.downloadAndInstallRuntime() }
                    }
                    .disabled(appState.isRuntimeBusy)
                } else if appState.runtimeUpdateAvailable != nil {
                    Button("Update Runtime") {
                        Task { await appState.downloadAndInstallRuntime() }
                    }
                    .disabled(appState.isRuntimeBusy)
                }
            }

            runtimeProgress

            Text(runtimeDetail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var runtimeProgress: some View {
        switch appState.runtimeInstallPhase {
        case .downloading(let fraction):
            ProgressView(value: fraction) {
                Text("Downloading Wine runtime…")
            }
        case .extracting:
            ProgressView("Extracting runtime…")
        case .failed(let message):
            VStack(alignment: .leading, spacing: 4) {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                Button("Dismiss") { appState.resetRuntimeInstallPhase() }
                    .font(.caption)
            }
        default:
            EmptyView()
        }
    }

    private var gptkStep: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                stepIcon(ok: appState.isD3DMetalAvailable)
                Text("D3DMetal (GPTK)")
                    .font(.headline)
                Spacer()
                if !appState.isD3DMetalAvailable {
                    Button("Install GPTK") {
                        Task { await appState.installGPTK() }
                    }
                    .disabled(
                        !appState.isRuntimeInstalled
                            || appState.isGPTKInstallBusy
                            || appState.isRuntimeBusy
                    )

                    Button("Choose File…") {
                        showGPTKFilePicker = true
                    }
                    .disabled(
                        !appState.isRuntimeInstalled
                            || appState.isGPTKInstallBusy
                            || appState.isRuntimeBusy
                    )
                }
            }

            gptkInstallProgress

            Text(gptkDetail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !appState.isD3DMetalAvailable {
                Link("Download Game Porting Toolkit 4.x from Apple",
                     destination: GPTKInstaller.appleDownloadPage)
                    .font(.callout)
            }
        }
    }

    @ViewBuilder
    private var gptkInstallProgress: some View {
        switch appState.gptkInstallPhase {
        case .working(let step):
            ProgressView(gptkStepMessage(step))
        case .failed(let message):
            VStack(alignment: .leading, spacing: 4) {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Dismiss") { appState.resetGPTKInstallPhase() }
                    .font(.caption)
            }
        default:
            EmptyView()
        }
    }

    private var gptkDetail: String {
        if appState.isD3DMetalAvailable {
            return "D3DMetal is installed for DirectX 11."
        }
        if !appState.isRuntimeInstalled {
            return "Download the Wine runtime first, then install GPTK."
        }
        return """
        Download Game Porting Toolkit 4.x from Apple (free developer account). Open the .dmg, then click \
        Install GPTK — GW2onMac will find it on your Mac, install Metal Shader Converter, and copy D3DMetal.
        """
    }

    private func gptkStepMessage(_ step: GPTKInstallStep) -> String {
        switch step {
        case .searching:
            return "Looking for Game Porting Toolkit…"
        case .mountingDMG(let name):
            return "Mounting \(name)…"
        case .installingShaderConverter:
            return "Installing Metal Shader Converter (admin password may be required)…"
        case .mountingEvaluationEnvironment:
            return "Opening evaluation environment…"
        case .copyingD3DMetal:
            return "Copying D3DMetal.framework…"
        case .complete:
            return "GPTK install complete."
        }
    }

    private var prefixStep: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                stepIcon(ok: appState.hasPrefix)
                Text("GW2 prefix")
                    .font(.headline)
                Spacer()
                if !appState.hasPrefix {
                    Button("Create Prefix") {
                        Task { await createPrefix() }
                    }
                    .disabled(isBusy || appState.isRuntimeBusy)
                }
            }
            Text("Creates a 64-bit Wine bottle tuned for Guild Wars 2.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var gameInstallStep: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                stepIcon(ok: appState.isGameInstalled)
                Text("Guild Wars 2 installed")
                    .font(.headline)
                Spacer()
                if appState.hasPrefix, !appState.isGameInstalled {
                    Button("Install GW2") {
                        Task { await appState.downloadAndRunGW2Setup() }
                    }
                    .disabled(appState.isGW2InstallBusy || !appState.hasPrefix)

                    Button("Import…") { showImportPicker = true }
                        .disabled(appState.isGW2InstallBusy || !appState.hasPrefix)
                }
            }

            gw2InstallProgress

            Text("Downloads Gw2Setup-64.exe from ArenaNet and launches the installer, or import an existing install folder.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var gw2InstallProgress: some View {
        switch appState.gw2InstallPhase {
        case .downloading(let fraction):
            ProgressView(value: fraction) {
                Text("Downloading Gw2Setup…")
            }
        case .launching:
            ProgressView("Launching Gw2Setup…")
        case .waitingForGame:
            ProgressView("Waiting for game install…")
        case .importing:
            ProgressView("Copying game files…")
        case .failed(let message):
            VStack(alignment: .leading, spacing: 4) {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Dismiss") { appState.resetGW2InstallPhase() }
                    .font(.caption)
            }
        default:
            EmptyView()
        }
    }

    private var runtimeDetail: String {
        if appState.isRuntimeInstalled {
            if let update = appState.runtimeUpdateAvailable {
                return "Runtime installed. Update v\(update.major).\(update.minor).\(update.patch) available."
            }
            return "Wine runtime is installed."
        }
        return """
        Download the Wine 11 runtime built from CrossOver FOSS sources (~450 MB).

        Legacy TyriaSilicon installs at com.tyriasilicon.app are detected automatically.
        Override URLs with GW2ONMAC_WINE_RUNTIME_URL for local testing.
        """
    }

    @ViewBuilder
    private func stepIcon(ok: Bool) -> some View {
        Image(systemName: ok ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(ok ? .green : .secondary)
    }

    @ViewBuilder
    private func setupStep(title: String, ok: Bool, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                stepIcon(ok: ok)
                Text(title)
                    .font(.headline)
            }
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func createPrefix() async {
        isBusy = true
        defer { isBusy = false }

        do {
            try await appState.createPrefix()
            statusMessage = "Prefix ready at \(appState.bottleManager.bottleURL.path)"
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
