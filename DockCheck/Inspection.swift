import Foundation

struct InspectionCheck: Identifiable {
    enum Status: String {
        case verified = "Verified"
        case notEvidenced = "Not evidenced"
        case manualReview = "Manual review"
    }

    struct Frame: Codable, Identifiable {
        let name: String
        let timestamp: String
        var jpegData: Data? = nil

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

struct InspectionReview: Codable {
    enum Decision: String, CaseIterable, Codable, Identifiable {
        case pending = "Pending"
        case accepted = "Accepted"
        case followUp = "Follow-up required"

        var id: Self { self }
    }

    var decision: Decision = .pending
    var note = ""
    var frameIDs: Set<String>?

    var trimmedNote: String { note.trimmingCharacters(in: .whitespacesAndNewlines) }
}

struct InspectionReport {
    let inspectionName: String
    let checks: [InspectionCheck]
    let reviews: [Int: InspectionReview]

    var reviewedCount: Int {
        checks.filter { decision(for: $0) != .pending }.count
    }

    var followUpChecks: [InspectionCheck] {
        checks.filter { decision(for: $0) == .followUp }
    }

    var followUpCount: Int { followUpChecks.count }

    var text: String {
        let sections = checks.map { check in
            let review = reviews[check.id] ?? InspectionReview()
            let evidence = check.frames.isEmpty
                ? "No frames attached"
                : check.frames.map(\.timestamp).joined(separator: ", ")
            var lines = [
                check.title,
                "Evidence: \(check.status.rawValue) (\(evidence))",
                check.observation,
                "Review decision: \(review.decision.rawValue)",
            ]
            if !review.trimmedNote.isEmpty {
                lines.append("Note: \(review.trimmedNote)")
            }
            return lines.joined(separator: "\n")
        }
        return ([
            "DockCheck — Outbound package · \(inspectionName)",
            "\(reviewedCount) of \(checks.count) reviewed · \(followUpCount) require follow-up",
        ] + sections).joined(separator: "\n\n")
    }

    private func decision(for check: InspectionCheck) -> InspectionReview.Decision {
        reviews[check.id]?.decision ?? .pending
    }
}
