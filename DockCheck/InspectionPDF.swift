import CoreText
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct InspectionPDF: FileDocument {
    static let readableContentTypes: [UTType] = [.pdf]

    let data: Data

    init(report: InspectionReport) {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let content = page.insetBy(dx: 42, dy: 44)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [kCGPDFContextTitle as String: "DockCheck · Lot \(report.lot)"]

        data = UIGraphicsPDFRenderer(bounds: page, format: format).pdfData { context in
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 5
            let text = NSAttributedString(string: report.text, attributes: [
                .font: UIFont.systemFont(ofSize: 13),
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraph,
            ])
            let framesetter = CTFramesetterCreateWithAttributedString(text as CFAttributedString)
            let path = CGPath(rect: content, transform: nil)
            var offset = 0

            while offset < text.length {
                let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(offset, 0), path, nil)
                let visible = CTFrameGetVisibleStringRange(frame)
                context.beginPage()
                let graphics = context.cgContext
                graphics.saveGState()
                graphics.translateBy(x: 0, y: page.height)
                graphics.scaleBy(x: 1, y: -1)
                graphics.textMatrix = .identity
                CTFrameDraw(frame, graphics)
                graphics.restoreGState()
                guard visible.length > 0 else { break }
                offset = visible.location + visible.length
            }

            let evidence = report.checks.flatMap { check in
                check.frames.compactMap { frame -> (caption: String, image: UIImage)? in
                    guard let image = UIImage(named: frame.name + ".jpg") else { return nil }
                    return ("\(check.title) · \(frame.timestamp)", image)
                }
            }

            for (index, entry) in evidence.enumerated() {
                let slot = index % 2
                if slot == 0 {
                    context.beginPage()
                    ("DockCheck · Lot \(report.lot) — Evidence" as NSString).draw(
                        at: content.origin,
                        withAttributes: [.font: UIFont.boldSystemFont(ofSize: 18), .foregroundColor: UIColor.black]
                    )
                }
                let top = content.minY + 44 + CGFloat(slot) * 340
                (entry.caption as NSString).draw(
                    at: CGPoint(x: content.minX, y: top),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 13), .foregroundColor: UIColor.black]
                )
                let scale = min(content.width / entry.image.size.width, 300 / entry.image.size.height)
                entry.image.draw(in: CGRect(
                    x: content.minX, y: top + 24,
                    width: entry.image.size.width * scale,
                    height: entry.image.size.height * scale
                ))
            }
        }
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
