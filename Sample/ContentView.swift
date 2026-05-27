import SwiftUI
import Scanner

struct ContentView: View {
    // Replace with your actual API key
    private let apiKey = "sk_live_your_api_key_here"

    @State private var scanType: ScanType = .qr
    @State private var selectedAPIStyle: APIStyle?
    @State private var lastResult: ScanResult?
    @State private var showResult = false

    enum APIStyle {
        case callback
        case stream
        case oneShot
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Scanner SDK Sample")
                    .font(.title)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Scan Type")
                        .font(.headline)
                    Picker("Scan Type", selection: $scanType) {
                        Text("QR Code").tag(ScanType.qr)
                        Text("Barcode").tag(ScanType.barcode)
                    }
                    .pickerStyle(.segmented)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)

                VStack(spacing: 12) {
                    Text("Choose API Style")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    NavigationLink(
                        destination: ScannerScreen(
                            apiKey: apiKey,
                            scanType: scanType,
                            apiStyle: .callback,
                            onResult: { result in
                                lastResult = result
                                showResult = true
                            }
                        )
                    ) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Callback Style")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("scanner.start(onResult:, onError:)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                    }

                    NavigationLink(
                        destination: ScannerScreen(
                            apiKey: apiKey,
                            scanType: scanType,
                            apiStyle: .stream,
                            onResult: { result in
                                lastResult = result
                                showResult = true
                            }
                        )
                    ) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Stream Style")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("scanner.stream(in:, type:)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(10)
                    }

                    NavigationLink(
                        destination: ScannerScreen(
                            apiKey: apiKey,
                            scanType: scanType,
                            apiStyle: .oneShot,
                            onResult: { result in
                                lastResult = result
                                showResult = true
                            }
                        )
                    ) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("One-Shot (Async/Await)")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("try await scanner.scan(in:, type:)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.purple)
                        .cornerRadius(10)
                    }
                }

                if let result = lastResult {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Last Result")
                            .font(.headline)
                        ResultView(result: result)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ContentView()
}
