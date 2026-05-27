import SwiftUI
import Scanner

struct ScannerScreen: View {
    let apiKey: String
    let scanType: ScanType
    let apiStyle: ContentView.APIStyle
    let onResult: (ScanResult) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var scanner: Scanner?
    @State private var scannerView: ScannerView?
    @State private var isScanning = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        ZStack {
            ScannerViewRepresentable(
                scanner: $scanner,
                scannerView: $scannerView,
                apiKey: apiKey
            )
            .ignoresSafeArea()
            .onAppear {
                startScanning()
            }
            .onDisappear {
                stopScanning()
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                Spacer()
            }
            .zIndex(1)

            if showError, let errorMessage = errorMessage {
                VStack {
                    Text("Error")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.body)
                    Button("Dismiss") {
                        showError = false
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(radius: 5)
                .padding()
                .zIndex(2)
            }
        }
        .alert("Scan Error", isPresented: $showError, actions: {
            Button("OK") { showError = false }
        }, message: {
            Text(errorMessage ?? "Unknown error")
        })
    }

    private func startScanning() {
        guard let scanner = scanner, let scannerView = scannerView else { return }

        isScanning = true

        switch apiStyle {
        case .callback:
            startWithCallback(scanner: scanner, scannerView: scannerView)

        case .stream:
            startWithStream(scanner: scanner, scannerView: scannerView)

        case .oneShot:
            startWithOneShot(scanner: scanner, scannerView: scannerView)
        }
    }

    // Style 1: Callback-based API
    // scanner.start(in:, type:, onResult:, onError:)
    private func startWithCallback(scanner: Scanner, scannerView: ScannerView) {
        scanner.start(
            in: scannerView,
            type: scanType,
            onResult: { result in
                isScanning = false
                onResult(result)
                dismiss()
            },
            onError: { error in
                isScanning = false
                errorMessage = error.localizedDescription
                showError = true
            }
        )
    }

    // Style 2: AsyncStream-based API
    // for await result in scanner.stream(in:, type:) { }
    private func startWithStream(scanner: Scanner, scannerView: ScannerView) {
        Task {
            do {
                for try await result in scanner.stream(in: scannerView, type: scanType) {
                    isScanning = false
                    onResult(result)
                    await MainActor.run {
                        dismiss()
                    }
                    break
                }
            } catch {
                isScanning = false
                errorMessage = (error as? ScannerError)?.localizedDescription ?? error.localizedDescription
                await MainActor.run {
                    showError = true
                }
            }
        }
    }

    // Style 3: Async/await one-shot API
    // let result = try await scanner.scan(in:, type:)
    private func startWithOneShot(scanner: Scanner, scannerView: ScannerView) {
        Task {
            do {
                let result = try await scanner.scan(in: scannerView, type: scanType)
                isScanning = false
                onResult(result)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                isScanning = false
                errorMessage = (error as? ScannerError)?.localizedDescription ?? error.localizedDescription
                await MainActor.run {
                    showError = true
                }
            }
        }
    }

    private func stopScanning() {
        guard let scanner = scanner, let scannerView = scannerView else { return }
        scanner.stop(view: scannerView)
        isScanning = false
    }
}

// SwiftUI wrapper for ScannerViewRepresentable
struct ScannerViewRepresentable: UIViewRepresentable {
    @Binding var scanner: Scanner?
    @Binding var scannerView: ScannerView?
    let apiKey: String

    func makeUIView(context: Context) -> UIView {
        let config = ScannerConfig(apiKey: apiKey)
        let scannerInstance = Scanner(config: config)
        let viewInstance = ScannerView()

        scanner = scannerInstance
        scannerView = viewInstance

        return viewInstance
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

#Preview {
    ScannerScreen(
        apiKey: "sk_live_test",
        scanType: .qr,
        apiStyle: .callback,
        onResult: { _ in }
    )
}
