@preconcurrency import AVFoundation
import Foundation
import UIKit

extension InspectionCheck.Frame {
    var image: UIImage? {
        if let jpegData {
            return UIImage(data: jpegData)
        }
        return UIImage(named: name + ".jpg")
    }
}

struct VideoInspection: Codable {
    let filename: String
    let frames: [InspectionCheck.Frame]
    var reviews: [Int: InspectionReview] = [:]

    var checks: [InspectionCheck] {
        InspectionCheck.sample.map { check in
            let selected = reviews[check.id]?.frameIDs ?? []
            return InspectionCheck(
                id: check.id,
                title: check.title,
                status: .manualReview,
                observation: "Review the sampled frames and attach any that support your decision.",
                frames: frames.filter { selected.contains($0.id) }
            )
        }
    }

    static func load() throws -> Self? {
        do {
            let data = try Data(contentsOf: storageURL)
            return try PropertyListDecoder().decode(Self.self, from: data)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return nil
        }
    }

    func save() throws {
        let url = Self.storageURL
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        try encoder.encode(self).write(to: url, options: .atomic)
    }

    private static var storageURL: URL {
        URL.applicationSupportDirectory.appendingPathComponent("DockCheck/video-inspection.plist")
    }
}

enum VideoFrameService {
    enum ImportError: LocalizedError {
        case fileTooLarge
        case unsupportedDuration
        case noFrames

        var errorDescription: String? {
            switch self {
            case .fileTooLarge: "Choose a video smaller than 250 MB."
            case .unsupportedDuration: "Choose a video between 1 second and 2 minutes long."
            case .noFrames: "No readable video frames were found in this file."
            }
        }
    }

    static func load(from url: URL) async throws -> VideoInspection {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }

        let values = try url.resourceValues(forKeys: [.nameKey, .fileSizeKey])
        if let size = values.fileSize, size > 250_000_000 {
            throw ImportError.fileTooLarge
        }

        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, (1...120).contains(duration) else {
            throw ImportError.unsupportedDuration
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 960, height: 960)
        generator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 10)
        generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 10)

        let count = min(12, max(2, Int(duration.rounded(.up))))
        var frames: [InspectionCheck.Frame] = []
        var seenTimes: Set<Int> = []
        for index in 0..<count {
            try Task.checkCancellation()
            let seconds = duration * (Double(index) + 0.5) / Double(count)
            let requestedTime = CMTime(seconds: seconds, preferredTimescale: 600)
            guard let result = try? await generator.image(at: requestedTime) else { continue }
            let actual = result.actualTime.seconds
            guard actual.isFinite, (0...duration).contains(actual) else { continue }
            let milliseconds = Int((actual * 1_000).rounded())
            guard !seenTimes.contains(milliseconds),
                  let jpeg = UIImage(cgImage: result.image).jpegData(compressionQuality: 0.75) else {
                continue
            }
            seenTimes.insert(milliseconds)
            let timestamp = String(format: "%02d:%02d.%03d",
                                   milliseconds / 60_000, milliseconds / 1_000 % 60, milliseconds % 1_000)
            frames.append(.init(name: "video-\(milliseconds)", timestamp: timestamp, jpegData: jpeg))
        }

        try Task.checkCancellation()
        guard !frames.isEmpty else { throw ImportError.noFrames }
        return VideoInspection(filename: values.name ?? url.lastPathComponent,
                               frames: frames.sorted { $0.timestamp < $1.timestamp })
    }
}
