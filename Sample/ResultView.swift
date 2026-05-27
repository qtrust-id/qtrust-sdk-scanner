import SwiftUI
import Scanner

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

            // Confidence
            VStack(alignment: .leading, spacing: 8) {
                Text("Confidence")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    ProgressView(value: result.confidence, total: 1.0)
                    Text(String(format: "%.0f%%", result.confidence * 100))
                        .font(.body)
                        .fontWeight(.semibold)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }

            // Bounding Box
            if let bbox = result.boundingBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bounding Box")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("x: \(String(format: "%.2f", bbox.x))")
                            .font(.caption)
                        Text("y: \(String(format: "%.2f", bbox.y))")
                            .font(.caption)
                        Text("width: \(String(format: "%.2f", bbox.width))")
                            .font(.caption)
                        Text("height: \(String(format: "%.2f", bbox.height))")
                            .font(.caption)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
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
    ResultView(
        result: ScanResult(
            data: "https://example.com",
            format: "QR_CODE",
            confidence: 0.95,
            boundingBox: BoundingBox(x: 10, y: 20, width: 100, height: 100)
        )
    )
    .padding()
}
