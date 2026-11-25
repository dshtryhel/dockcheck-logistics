import SwiftUI
import UIKit
import UniformTypeIdentifiers

@main
struct DockCheckApp: App {
    var body: some Scene {
        WindowGroup {
            InspectionView()
        }
    }
}

private struct InspectionView: View {
    @AppStorage("inspection-reviews-lot-a-104") private var reviewData = Data()
    @State private var selectedCheck: InspectionCheck?
    @State private var followUpOnly = false
    @State private var pdf: InspectionPDF?
    @State private var exportingPDF = false
    @State private var exportError: String?

    private let lot = "A-104"
    private let checks = InspectionCheck.sample

    private var reviews: [Int: InspectionReview] {
        (try? JSONDecoder().decode([Int: InspectionReview].self, from: reviewData)) ?? [:]
    }

    var body: some View {
        let currentReviews = reviews
        let report = InspectionReport(lot: lot, checks: checks, reviews: currentReviews)

        NavigationStack {
            List {
                Section {
                    Toggle("Show only follow-up items", isOn: $followUpOnly)
                }

                Section {
                    let visibleChecks = followUpOnly ? report.followUpChecks : checks
                    if visibleChecks.isEmpty {
                        Text("No items require follow-up.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(visibleChecks) { check in
                        let review = currentReviews[check.id] ?? InspectionReview()
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

                            if !review.trimmedNote.isEmpty {
                                Text(review.trimmedNote)
                            }

                            Button {
                                selectedCheck = check
                            } label: {
                                Label("Edit review", systemImage: "square.and.pencil")
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(check.title)
                                Text(check.status.rawValue)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if review.decision != .pending {
                                    Text(review.decision.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(review.decision == .followUp ? Color.orange : Color.green)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("Outbound package · Lot \(lot)")
                } footer: {
                    Text("“Not evidenced” means the available frames do not show enough to confirm the step.")
                }

                Section("Review summary") {
                    LabeledContent("Reviewed", value: "\(report.reviewedCount) of \(checks.count)")
                    LabeledContent("Follow-up required", value: "\(report.followUpCount)")
                    ShareLink(item: report.text, subject: Text("DockCheck inspection · Lot \(lot)")) {
                        Label("Share summary", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        pdf = InspectionPDF(report: report)
                        exportingPDF = true
                    } label: {
                        Label("Export PDF", systemImage: "doc.richtext")
                    }
                }
            }
            .navigationTitle("DockCheck")
            .fileExporter(
                isPresented: $exportingPDF,
                document: pdf,
                contentType: .pdf,
                defaultFilename: "DockCheck-\(lot)"
            ) { result in
                if case .failure(let error) = result {
                    exportError = error.localizedDescription
                }
            }
            .alert("Couldn’t export PDF", isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )) {
                Button("OK", role: .cancel) { exportError = nil }
            } message: {
                Text(exportError ?? "")
            }
            .sheet(item: $selectedCheck) { check in
                ReviewEditor(check: check, review: currentReviews[check.id] ?? InspectionReview()) { review in
                    var updated = reviews
                    updated[check.id] = review
                    if let encoded = try? JSONEncoder().encode(updated) {
                        reviewData = encoded
                    }
                    selectedCheck = nil
                }
            }
        }
    }
}

private struct ReviewEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: InspectionReview

    let check: InspectionCheck
    let onSave: (InspectionReview) -> Void

    init(check: InspectionCheck, review: InspectionReview, onSave: @escaping (InspectionReview) -> Void) {
        self.check = check
        self.onSave = onSave
        _draft = State(initialValue: review)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Frame evidence", value: check.status.rawValue)
                    Picker("Review decision", selection: $draft.decision) {
                        ForEach(InspectionReview.Decision.allCases) { decision in
                            Text(decision.rawValue).tag(decision)
                        }
                    }
                } header: {
                    Text(check.title)
                }

                Section("Notes") {
                    TextField("Add a note", text: $draft.note, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .navigationTitle("Edit review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(draft) }
                }
            }
        }
    }
}
