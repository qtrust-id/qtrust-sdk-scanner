import SwiftUI
import QTrustScanner

struct ResultView: View {
    let result: ScanResult
    @State private var copied = false

    var body: some View {
        VStack(spacing: 16) {
            // Data
            VStack(alignment: .leading, spacing: 8) {
                Text("Data")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    Text(result.data)
                        .font(.body)
                        .lineLimit(3)
                    Spacer()
                    Button(action: copyData) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }

            // Format
            VStack(alignment: .leading, spacing: 8) {
                Text("Format")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(result.format)
                    .font(.body)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Bounding Box
            VStack(alignment: .leading, spacing: 8) {
                Text("Bounding Box")
                    .font(.caption)
                    .foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("x: \(result.boundingBox.x)")
                        .font(.caption)
                    Text("y: \(result.boundingBox.y)")
                        .font(.caption)
                    Text("width: \(result.boundingBox.width)")
                        .font(.caption)
                    Text("height: \(result.boundingBox.height)")
                        .font(.caption)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if copied {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Copied to clipboard")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .transition(.opacity)
            }
        }
    }

    private func copyData() {
        UIPasteboard.general.string = result.data
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copied = false
            }
        }
    }
}

#Preview {
    let json = """
    {"data":"https://example.com","format":"QR_CODE","bounding_box":{"x":10,"y":20,"width":100,"height":100}}
    """.data(using: .utf8)!
    let result = try! JSONDecoder().decode(ScanResult.self, from: json)
    ResultView(result: result)
        .padding()
}
