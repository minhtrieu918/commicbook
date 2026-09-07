import AppKit
import Foundation
import PDFKit

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: render_pdf_pages.swift input.pdf output_dir\n", stderr)
    exit(2)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

guard let document = PDFDocument(url: inputURL) else {
    fputs("Cannot open PDF\n", stderr)
    exit(1)
}

let scale: CGFloat = 1.7
for index in 0..<document.pageCount {
    guard let page = document.page(at: index) else { continue }
    let box = page.bounds(for: .mediaBox)
    let width = Int(ceil(box.width * scale))
    let height = Int(ceil(box.height * scale))
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 32
    ) else { continue }
    NSGraphicsContext.saveGraphicsState()
    guard let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else { continue }
    NSGraphicsContext.current = graphics
    let context = graphics.cgContext
    context.setFillColor(NSColor.white.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.scaleBy(x: scale, y: scale)
    page.draw(with: .mediaBox, to: context)
    graphics.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    if let data = bitmap.representation(using: .png, properties: [:]) {
        let name = String(format: "page-%03d.png", index + 1)
        try data.write(to: outputURL.appendingPathComponent(name))
    }
}

print("Rendered \(document.pageCount) pages")
