// Frames each raw Simulator capture for the App Store: a two-line caption above the screenshot, on the color of the
// Phase it shows. Usage: swift AppStore/Screenshots/compose.swift <raw folder> <output folder>
import AppKit
import ImageIO
import UniformTypeIdentifiers

/// One App Store screenshot: the capture it frames, its caption, and the colors from DESIGN.md it sits in.
struct Shot {
    let capture: String
    let caption: (accent: String, rest: String)
    let field: UInt32
    let ring: UInt32
    let track: UInt32
    /// The most the capture is enlarged, so a small Watch capture stays sharp.
    var maxScale = CGFloat.infinity
    /// An iPhone capture drawn behind this one, which then stands in front of it at the bottom right.
    var behind: String?
}

let shots = [
    Shot(
        capture: "1-describe.png", caption: ("Say it.", "Temper plans it."),
        field: 0x11151D, ring: 0xE6B566, track: 0x2E3643),
    Shot(
        capture: "2-work.png", caption: ("Readable from", "across the room"),
        field: 0x351C17, ring: 0xFFAE8A, track: 0x59332A),
    Shot(
        capture: "3-live-activity.png", caption: ("Stays on your", "Lock Screen"),
        field: 0x0F2A2B, ring: 0x86DCCB, track: 0x254A48),
    Shot(
        capture: "4-watch.png", caption: ("Heart rate and Zone", "on your wrist"),
        field: 0x18223F, ring: 0xAFC4FF, track: 0x2F3D66, maxScale: 1.7, behind: "4-iphone.png"),
    Shot(
        capture: "5-presets.png", caption: ("Presets,", "one tap away"),
        field: 0x0F2433, ring: 0x8FCBEF, track: 0x274A60),
]

/// The 6.9" iPhone size App Store Connect asks for, which it scales down for smaller iPhones.
let canvas = CGSize(width: 1320, height: 2868)
let margin: CGFloat = 96
let warmWhite: UInt32 = 0xF3F1EA
/// AppKit's text color key, by its raw value, since `make lint` bans the SwiftUI modifier of the same name.
let textColor = NSAttributedString.Key("NSColor")

func color(_ hex: UInt32) -> NSColor {
    NSColor(
        srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

func rounded(_ size: CGFloat) -> NSFont {
    let font = NSFont.systemFont(ofSize: size, weight: .bold)
    return font.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: size) } ?? font
}

/// One caption size for every shot, the largest at which every line fits between the margins.
let captionSize: CGFloat = {
    var size: CGFloat = 128
    let lines = shots.flatMap { [$0.caption.accent, $0.caption.rest] }
    while size > 40,
        lines.contains(where: {
            ($0 as NSString).size(withAttributes: [.font: rounded(size)]).width > canvas.width - 2 * margin
        })
    {
        size -= 2
    }
    return size
}()

func load(_ name: String, from raw: URL) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(raw.appending(path: name) as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

/// The largest frame of `capture`'s shape that fits `size`, enlarging it at most `maxScale` times.
func fitted(_ capture: CGImage, in size: CGSize, maxScale: CGFloat = .infinity) -> CGSize {
    let scale = min(size.width / CGFloat(capture.width), size.height / CGFloat(capture.height), maxScale)
    return CGSize(width: CGFloat(capture.width) * scale, height: CGFloat(capture.height) * scale)
}

/// Draws a capture in `frame` with a shadow, its corners rounded past the display's own, and an outline.
func draw(_ capture: CGImage, in frame: CGRect, outline color: NSColor, on context: CGContext) {
    // A watch display is far rounder for its size than an iPhone's.
    let isWatch = CGFloat(capture.width) / CGFloat(capture.height) > 0.7
    let radius = frame.width * (isWatch ? 0.22 : 0.135)
    let outline = CGPath(roundedRect: frame, cornerWidth: radius, cornerHeight: radius, transform: nil)

    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: 24), blur: 80, color: NSColor.black.withAlphaComponent(0.45).cgColor)
    context.addPath(outline)
    context.setFillColor(NSColor.black.cgColor)
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(outline)
    context.clip()
    // Drawn upside down to undo the flip, since CGContext draws images with a bottom-left origin.
    context.translateBy(x: frame.minX, y: frame.maxY)
    context.scaleBy(x: 1, y: -1)
    context.interpolationQuality = .high
    context.draw(capture, in: CGRect(origin: .zero, size: frame.size))
    context.restoreGState()

    context.addPath(outline)
    context.setStrokeColor(color.cgColor)
    context.setLineWidth(6)
    context.strokePath()
}

func compose(_ shot: Shot, from raw: URL, to output: URL) throws {
    guard let capture = load(shot.capture, from: raw) else {
        print("skipped \(shot.capture): not found in \(raw.path)")
        return
    }
    // No alpha channel: App Store Connect rejects screenshots with one.
    guard let sRGB = CGColorSpace(name: CGColorSpace.sRGB),
        let context = CGContext(
            data: nil, width: Int(canvas.width), height: Int(canvas.height), bitsPerComponent: 8, bytesPerRow: 0,
            space: sRGB, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { fatalError("no bitmap context") }
    // Top-left origin, as the layout below is written.
    context.translateBy(x: 0, y: canvas.height)
    context.scaleBy(x: 1, y: -1)
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)

    context.setFillColor(color(shot.field).cgColor)
    context.fill(CGRect(origin: .zero, size: canvas))

    // The caption: the first line in the Phase's ring color, the second in warm white, centered.
    let font = rounded(captionSize)
    let lineHeight = font.ascender - font.descender + font.leading
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let captionTop: CGFloat = 230
    for (index, (line, hex)) in [(shot.caption.accent, shot.ring), (shot.caption.rest, warmWhite)].enumerated() {
        let rect = CGRect(
            x: margin, y: captionTop + CGFloat(index) * lineHeight * 1.04, width: canvas.width - 2 * margin,
            height: lineHeight)
        (line as NSString).draw(
            in: rect, withAttributes: [.font: font, textColor: color(hex), .paragraphStyle: paragraph])
    }

    // The space below the caption.
    let top = captionTop + 2 * lineHeight * 1.04 + 96
    let area = CGRect(x: margin, y: top, width: canvas.width - 2 * margin, height: canvas.height - 120 - top)
    let outline = color(shot.track)

    if let name = shot.behind, let behind = load(name, from: raw) {
        // The iPhone at the left, full height, and the capture in front of it at the bottom right.
        draw(
            behind, in: CGRect(origin: area.origin, size: fitted(behind, in: area.size)), outline: outline, on: context)
        let front = fitted(capture, in: area.size, maxScale: shot.maxScale)
        let frame = CGRect(
            x: canvas.width - margin / 2 - front.width, y: area.maxY - front.height - 80, width: front.width,
            height: front.height)
        draw(capture, in: frame, outline: outline, on: context)
    } else {
        let size = fitted(capture, in: area.size, maxScale: shot.maxScale)
        let frame = CGRect(
            x: area.midX - size.width / 2, y: area.midY - size.height / 2, width: size.width, height: size.height)
        draw(capture, in: frame, outline: outline, on: context)
    }

    guard let image = context.makeImage(),
        let destination = CGImageDestinationCreateWithURL(
            output.appending(path: shot.capture) as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { fatalError("can't write \(shot.capture)") }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("can't write \(shot.capture)") }
    print("wrote \(output.appending(path: shot.capture).path)")
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    print("usage: swift compose.swift <raw folder> <output folder>")
    exit(2)
}
let raw = URL(filePath: arguments[1])
let output = URL(filePath: arguments[2])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for shot in shots {
    try compose(shot, from: raw, to: output)
}

// The Apple Watch set takes the Watch capture as it is: 416 × 496, a size App Store Connect accepts, with no alpha.
let watchCapture = raw.appending(path: "4-watch.png")
let watchShot = output.appending(path: "watch-1-running.png")
if FileManager.default.fileExists(atPath: watchCapture.path) {
    try? FileManager.default.removeItem(at: watchShot)
    try FileManager.default.copyItem(at: watchCapture, to: watchShot)
    print("wrote \(watchShot.path)")
}
