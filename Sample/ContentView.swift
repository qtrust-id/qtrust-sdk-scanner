import SwiftUI
import QTrustScanner

struct ContentView: View {
    // Replace with your actual API key
    private let apiKey = "sk_live_test"

    @State private var scanType: ScanType = .qr
    @State private var skipTutorial = true
    @State private var rawResult = false
    @State private var lastResult: ScanResult?

    enum APIStyle {
        case callback
        case stream
        case oneShot
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("QTrust Scanner")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(.label))
                        Text("Cloud-based QR & Barcode Scanner")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)

                    // Scan Type
                    sectionCard {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("SCAN TYPE")
                            Picker("Scan Type", selection: $scanType) {
                                Text("QR Code").tag(ScanType.qr)
                                Text("Barcode").tag(ScanType.barcode)
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    // Options
                    sectionCard {
                        VStack(spacing: 0) {
                            toggleRow(
                                title: "Skip Tutorial",
                                subtitle: "Langsung ke scanner tanpa tutorial",
                                isOn: $skipTutorial
                            )
                            Divider().padding(.leading, 16)
                            toggleRow(
                                title: "Raw Result",
                                subtitle: "Callback data langsung tanpa halaman result",
                                isOn: $rawResult
                            )
                        }
                    }

                    // API Style
                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel("API STYLE")
                            .padding(.horizontal, 4)

                        apiStyleButton(
                            title: "Callback",
                            subtitle: "scanner.start(onResult:, onError:)",
                            color: Color(red: 0.2, green: 0.5, blue: 1.0),
                            style: .callback
                        )
                        apiStyleButton(
                            title: "Stream",
                            subtitle: "scanner.stream(in:, type:)",
                            color: Color(red: 0.2, green: 0.78, blue: 0.45),
                            style: .stream
                        )
                        apiStyleButton(
                            title: "Async/Await",
                            subtitle: "try await scanner.scan(in:, type:)",
                            color: Color(red: 0.58, green: 0.34, blue: 0.92),
                            style: .oneShot
                        )
                    }

                    // Last Result
                    if let result = lastResult {
                        sectionCard {
                            VStack(alignment: .leading, spacing: 8) {
                                sectionLabel("LAST RESULT")
                                ResultView(result: result)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
        }
    }

    // MARK: - Components

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.secondary)
            .tracking(0.5)
    }

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
    }

    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(.vertical, 10)
    }

    private func apiStyleButton(title: String, subtitle: String, color: Color, style: APIStyle) -> some View {
        NavigationLink(
            destination: ScannerScreen(
                apiKey: apiKey,
                scanType: scanType,
                skipTutorial: skipTutorial,
                rawResult: rawResult,
                apiStyle: style,
                onResult: { result in
                    lastResult = result
                }
            )
        ) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.75))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(color)
            .cornerRadius(12)
        }
    }
}

#Preview {
    ContentView()
}
