import AppKit

struct ScreenshotSpec {
  let source: String
  let title: String
  let subtitle: String
  let output: String
}

let root = FileManager.default.currentDirectoryPath
let raw = "\(root)/assets/store-listing/ios-en-raw"
let outputDirectory = "\(root)/assets/store-listing/ios-en-store"
try FileManager.default.createDirectory(
  at: URL(fileURLWithPath: outputDirectory),
  withIntermediateDirectories: true
)

let screens = [
  ScreenshotSpec(
    source: "\(raw)/02-search.png",
    title: "Search Faster",
    subtitle: "Find public product information",
    output: "\(outputDirectory)/01-search-faster.png"
  ),
  ScreenshotSpec(
    source: "\(raw)/01-market.png",
    title: "Explore Cards",
    subtitle: "Browse publicly available product information",
    output: "\(outputDirectory)/02-explore-cards.png"
  ),
  ScreenshotSpec(
    source: "\(raw)/03-card-details.png",
    title: "Check Key Details",
    subtitle: "Review fees, limits, regions, and KYC guidance",
    output: "\(outputDirectory)/03-key-details.png"
  ),
  ScreenshotSpec(
    source: "\(raw)/04-region-availability.png",
    title: "Review Availability",
    subtitle: "See provider-published regional information",
    output: "\(outputDirectory)/04-availability.png"
  ),
  ScreenshotSpec(
    source: "\(raw)/05-card-wallet.png",
    title: "Your Card Wallet",
    subtitle: "Keep products for later reference",
    output: "\(outputDirectory)/05-card-wallet.png"
  ),
]

let canvas = NSSize(width: 1284, height: 2778)
let margin: CGFloat = 78
let topImageY: CGFloat = 126
let imageWidth: CGFloat = 900
let imageHeight = imageWidth * 2778 / 1284
let imageRect = NSRect(
  x: (canvas.width - imageWidth) / 2,
  y: topImageY,
  width: imageWidth,
  height: imageHeight
)

func drawText(_ string: String, in rect: NSRect, font: NSFont, color: NSColor) {
  let style = NSMutableParagraphStyle()
  style.alignment = .center
  style.lineBreakMode = .byWordWrapping
  (string as NSString).draw(
    in: rect,
    withAttributes: [
      .font: font,
      .foregroundColor: color,
      .paragraphStyle: style,
    ]
  )
}

for screen in screens {
  guard let image = NSImage(contentsOfFile: screen.source) else {
    fputs("Could not read \(screen.source)\n", stderr)
    exit(1)
  }

  guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(canvas.width),
    pixelsHigh: Int(canvas.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
  ) else {
    fputs("Could not make output bitmap\n", stderr)
    exit(1)
  }

  let context = NSGraphicsContext(bitmapImageRep: bitmap)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = context

  let background = NSGradient(
    colors: [
      NSColor(calibratedRed: 0.90, green: 0.96, blue: 1.0, alpha: 1.0),
      NSColor(calibratedRed: 0.96, green: 0.92, blue: 1.0, alpha: 1.0),
      NSColor(calibratedRed: 1.0, green: 0.93, blue: 0.96, alpha: 1.0),
    ],
    atLocations: [0.0, 0.52, 1.0],
    colorSpace: .deviceRGB
  )!
  background.draw(in: NSRect(origin: .zero, size: canvas), angle: -35)

  let headlineRect = NSRect(x: margin, y: 2450, width: canvas.width - margin * 2, height: 130)
  let subtitleRect = NSRect(x: margin, y: 2350, width: canvas.width - margin * 2, height: 80)
  drawText(screen.title, in: headlineRect, font: NSFont.systemFont(ofSize: 76, weight: .bold), color: NSColor(calibratedRed: 0.03, green: 0.11, blue: 0.25, alpha: 1))
  drawText(screen.subtitle, in: subtitleRect, font: NSFont.systemFont(ofSize: 34, weight: .medium), color: NSColor(calibratedRed: 0.27, green: 0.38, blue: 0.58, alpha: 1))

  let shadow = NSShadow()
  shadow.shadowColor = NSColor.black.withAlphaComponent(0.16)
  shadow.shadowBlurRadius = 28
  shadow.shadowOffset = NSSize(width: 0, height: -12)
  shadow.set()
  NSColor.white.withAlphaComponent(0.55).setFill()
  NSBezierPath(roundedRect: imageRect.insetBy(dx: -8, dy: -8), xRadius: 66, yRadius: 66).fill()

  NSGraphicsContext.saveGraphicsState()
  NSBezierPath(roundedRect: imageRect, xRadius: 56, yRadius: 56).addClip()
  image.draw(in: imageRect, from: NSRect(origin: .zero, size: image.size), operation: .sourceOver, fraction: 1.0)
  NSGraphicsContext.restoreGraphicsState()

  NSGraphicsContext.restoreGraphicsState()
  guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Could not encode \(screen.output)\n", stderr)
    exit(1)
  }
  try png.write(to: URL(fileURLWithPath: screen.output))
}
