import SwiftUI
import UIKit

@main
struct DockCheckApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                List {
                    Section {
                        ForEach(InspectionCheck.sample) { check in
                            DisclosureGroup {
                                Text(check.observation)
                                    .padding(.vertical, 4)

                                ForEach(check.frames) { frame in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(frame.timestamp)
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                        if let image = UIImage(named: frame.name + ".jpg") {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFit()
                                                .accessibilityLabel(Text("Inspection frame at \(frame.timestamp)"))
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(check.title)
                                    Text(check.status.rawValue)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } header: {
                        Text("Outbound package · Lot A-104")
                    } footer: {
                        Text("Offline sample with staged frames and predefined findings. “Not evidenced” means the available frames do not show enough to confirm the step.")
                    }
                }
                .navigationTitle("DockCheck")
            }
        }
    }
}

private struct InspectionCheck: Identifiable {
    enum Status: String {
        case verified = "Verified"
        case notEvidenced = "Not evidenced"
    }

    struct Frame: Identifiable {
        let name: String
        let timestamp: String

        var id: String { name }
    }

    let id: Int
    let title: String
    let status: Status
    let observation: String
    let frames: [Frame]

    static let sample: [Self] = [
        .init(id: 1, title: "Verify the package label", status: .verified,
              observation: "The label confirmation shows work order LOT A-104.",
              frames: [.init(name: "frame_000", timestamp: "00:02")]),
        .init(id: 2, title: "Read the QR code", status: .verified,
              observation: "The scan confirmation shows package ID PKG-4821.",
              frames: [.init(name: "frame_001", timestamp: "00:07")]),
        .init(id: 3, title: "Inspect all package surfaces", status: .notEvidenced,
              observation: "The frames show the top of the package. Review footage of all four sides before marking this check verified.",
              frames: [.init(name: "frame_002", timestamp: "00:12"),
                       .init(name: "frame_003", timestamp: "00:17")]),
        .init(id: 4, title: "Apply the security seal", status: .verified,
              observation: "A blue security seal is visible across the center seam.",
              frames: [.init(name: "frame_004", timestamp: "00:22")]),
        .init(id: 5, title: "Complete the inspection", status: .verified,
              observation: "The inspection-complete screen appears after the sealing frame.",
              frames: [.init(name: "frame_005", timestamp: "00:27")])
    ]
}
