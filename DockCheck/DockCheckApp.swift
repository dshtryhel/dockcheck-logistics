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
    @State private var errorMessage: String?
    @State private var importedVideo: VideoInspection?
    @State private var showingVideo = false
    @State private var choosingVideo = false
    @State private var confirmingReplacement = false
    @State private var importingVideo = false
    @State private var loadedSavedVideo = false

    private var activeVideo: VideoInspection? { showingVideo ? importedVideo : nil }

    private var reviews: [Int: InspectionReview] {
        if let activeVideo { return activeVideo.reviews }
        return (try? JSONDecoder().decode([Int: InspectionReview].self, from: reviewData)) ?? [:]
    }

    var body: some View {
        let video = activeVideo
        let inspectionName = video?.filename ?? "Lot A-104"
        let checks = video?.checks ?? InspectionCheck.sample
        let currentReviews = reviews
        let report = InspectionReport(inspectionName: inspectionName, checks: checks, reviews: currentReviews)

        NavigationStack {
            List {
                if let video {
                    Section {
                        DisclosureGroup("Video frames (\(video.frames.count))") {
                            ForEach(video.frames) { frame in
                                EvidenceFrameView(frame: frame)
                            }
                        }
                    } footer: {
                        Text("Attach frames to a checklist item in Edit review.")
                    }
                }

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
                                EvidenceFrameView(frame: frame)
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
                    Text("Outbound package · \(inspectionName)")
                } footer: {
                    if video == nil {
                        Text("“Not evidenced” means the available frames do not show enough to confirm the step.")
                    }
                }

                Section("Review summary") {
                    LabeledContent("Reviewed", value: "\(report.reviewedCount) of \(checks.count)")
                    LabeledContent("Follow-up required", value: "\(report.followUpCount)")
                    ShareLink(item: report.text, subject: Text("DockCheck inspection · \(inspectionName)")) {
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
            .disabled(importingVideo)
            .navigationTitle("DockCheck")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu("Inspection", systemImage: "ellipsis.circle") {
                        Button("Import video", systemImage: "film") {
                            if importedVideo == nil {
                                choosingVideo = true
                            } else {
                                confirmingReplacement = true
                            }
                        }
                        if importedVideo != nil {
                            if showingVideo {
                                Button("Open lot A-104") { switchInspection(showVideo: false) }
                            } else {
                                Button("Open imported inspection") { switchInspection(showVideo: true) }
                            }
                        }
                    }
                    .disabled(importingVideo)
                }
            }
            .overlay {
                if importingVideo {
                    ProgressView("Extracting video frames…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .task {
                guard !loadedSavedVideo else { return }
                loadedSavedVideo = true
                do {
                    importedVideo = try VideoInspection.load()
                    showingVideo = importedVideo != nil
                } catch {
                    errorMessage = "The saved video inspection couldn’t be opened."
                }
            }
            .confirmationDialog("Replace imported inspection?", isPresented: $confirmingReplacement, titleVisibility: .visible) {
                Button("Choose replacement video", role: .destructive) { choosingVideo = true }
            } message: {
                Text("After the new video is imported, it will replace the previous video’s frames, decisions, and notes.")
            }
            .fileImporter(isPresented: $choosingVideo, allowedContentTypes: [.movie]) { result in
                switch result {
                case .success(let url):
                    importingVideo = true
                    Task { await importVideo(from: url) }
                case .failure(let error):
                    errorMessage = "Couldn’t open video. \(error.localizedDescription)"
                }
            }
            .fileExporter(
                isPresented: $exportingPDF,
                document: pdf,
                contentType: .pdf,
                defaultFilename: video == nil ? "DockCheck-A-104" : "DockCheck-video-inspection"
            ) { result in
                if case .failure(let error) = result {
                    errorMessage = "Couldn’t export PDF. \(error.localizedDescription)"
                }
            }
            .alert("DockCheck", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(item: $selectedCheck) { check in
                ReviewEditor(
                    check: check,
                    review: currentReviews[check.id] ?? InspectionReview(),
                    availableFrames: video?.frames ?? []
                ) { review in
                    try saveReview(review, checkID: check.id)
                    selectedCheck = nil
                }
            }
        }
    }

    private func switchInspection(showVideo: Bool) {
        showingVideo = showVideo
        followUpOnly = false
    }

    @MainActor
    private func importVideo(from url: URL) async {
        defer { importingVideo = false }
        do {
            let imported = try await VideoFrameService.load(from: url)
            try imported.save()
            importedVideo = imported
            switchInspection(showVideo: true)
        } catch {
            errorMessage = "Couldn’t import video. \(error.localizedDescription)"
        }
    }

    private func saveReview(_ review: InspectionReview, checkID: Int) throws {
        if var video = activeVideo {
            video.reviews[checkID] = review
            try video.save()
            importedVideo = video
        } else {
            var updated = reviews
            updated[checkID] = review
            reviewData = try JSONEncoder().encode(updated)
        }
    }
}

private struct EvidenceFrameView: View {
    let frame: InspectionCheck.Frame

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(frame.timestamp)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            if let image = frame.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel(Text("Inspection frame at \(frame.timestamp)"))
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ReviewEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: InspectionReview
    @State private var showSaveError = false

    let check: InspectionCheck
    let availableFrames: [InspectionCheck.Frame]
    let onSave: (InspectionReview) throws -> Void

    init(
        check: InspectionCheck, review: InspectionReview,
        availableFrames: [InspectionCheck.Frame], onSave: @escaping (InspectionReview) throws -> Void
    ) {
        self.check = check
        self.availableFrames = availableFrames
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

                if !availableFrames.isEmpty {
                    Section("Attach video frames") {
                        ForEach(availableFrames) { frame in
                            Toggle(isOn: selection(for: frame)) {
                                EvidenceFrameView(frame: frame)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit review")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Couldn’t save the review", isPresented: $showSaveError) {
                Button("OK", role: .cancel) {}
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            try onSave(draft)
                        } catch {
                            showSaveError = true
                        }
                    }
                }
            }
        }
    }

    private func selection(for frame: InspectionCheck.Frame) -> Binding<Bool> {
        Binding(
            get: { draft.frameIDs?.contains(frame.id) ?? false },
            set: { isSelected in
                var selected = draft.frameIDs ?? []
                if isSelected {
                    selected.insert(frame.id)
                } else {
                    selected.remove(frame.id)
                }
                draft.frameIDs = selected
            }
        )
    }
}
