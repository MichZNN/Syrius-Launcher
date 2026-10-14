// Generates the macOS app icon set: a green four-pointed star (in the style
// of the Syrius icon) on the front card of a fanned stack of wallet cards.
//
// Usage:
//   swift tool/generate_app_icon.swift macos/Runner/Assets.xcassets/AppIcon.appiconset
import AppKit

let args = CommandLine.arguments
guard args.count == 2 else {
  FileHandle.standardError.write("usage: generate_app_icon.swift <output dir>\n".data(using: .utf8)!)
  exit(2)
}
let outputDir = URL(fileURLWithPath: args[1])

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
  CGColor(
    srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
    green: CGFloat((hex >> 8) & 0xFF) / 255,
    blue: CGFloat(hex & 0xFF) / 255,
    alpha: alpha
  )
}

/// Four-pointed star with concave sides, centred on `center`.
func starPath(center c: CGPoint, radius r: CGFloat, waist: CGFloat) -> CGPath {
  let path = CGMutablePath()
  let tips = [
    CGPoint(x: c.x, y: c.y + r), CGPoint(x: c.x + r, y: c.y),
    CGPoint(x: c.x, y: c.y - r), CGPoint(x: c.x - r, y: c.y),
  ]
  // Control points sit close to the centre, which makes the sides concave.
  let k = r * waist
  let controls = [
    CGPoint(x: c.x + k, y: c.y + k), CGPoint(x: c.x + k, y: c.y - k),
    CGPoint(x: c.x - k, y: c.y - k), CGPoint(x: c.x - k, y: c.y + k),
  ]
  path.move(to: tips[0])
  for i in 0..<4 {
    path.addQuadCurve(to: tips[(i + 1) % 4], control: controls[i])
  }
  path.closeSubpath()
  return path
}

func roundedCard(center: CGPoint, size: CGSize, radius: CGFloat, angle: CGFloat) -> CGPath {
  var transform = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: angle)
  let rect = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
  return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: &transform)
}

func render(size: Int) -> Data {
  let s = CGFloat(size)
  let u = s / 1024 // design units are on a 1024 grid
  let space = CGColorSpace(name: CGColorSpace.sRGB)!
  let ctx = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
  )!

  // macOS icon body: 824/1024, centred.
  let body = CGRect(x: 100 * u, y: 100 * u, width: 824 * u, height: 824 * u)
  let bodyPath = CGPath(
    roundedRect: body, cornerWidth: 185 * u, cornerHeight: 185 * u, transform: nil
  )
  ctx.saveGState()
  ctx.setShadow(offset: CGSize(width: 0, height: -10 * u), blur: 28 * u, color: color(0x000000, alpha: 0.4))
  ctx.addPath(bodyPath)
  ctx.setFillColor(color(0x121417))
  ctx.fillPath()
  ctx.restoreGState()

  ctx.saveGState()
  ctx.addPath(bodyPath)
  ctx.clip()

  // Fanned stack of wallet cards (back to front).
  let cardSize = CGSize(width: 560 * u, height: 400 * u)
  let cards: [(dx: CGFloat, dy: CGFloat, angle: CGFloat, fill: UInt32, stroke: UInt32)] = [
    (70, 70, 0.20, 0x1D232B, 0x2A323D),
    (35, 35, 0.10, 0x232A34, 0x333C48),
    (0, 0, 0.0, 0x2B3541, 0x3D4756),
  ]
  let base = CGPoint(x: 490 * u, y: 480 * u)
  for card in cards {
    let path = roundedCard(
      center: CGPoint(x: base.x + card.dx * u, y: base.y + card.dy * u),
      size: cardSize, radius: 56 * u, angle: card.angle
    )
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8 * u), blur: 24 * u, color: color(0x000000, alpha: 0.45))
    ctx.addPath(path)
    ctx.setFillColor(color(card.fill))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.addPath(path)
    ctx.setStrokeColor(color(card.stroke))
    ctx.setLineWidth(max(1, 4 * u))
    ctx.strokePath()
  }

  // Green star on the front card, with a soft glow and a green gradient.
  let star = starPath(center: base, radius: 165 * u, waist: 0.13)
  ctx.saveGState()
  ctx.setShadow(offset: .zero, blur: 40 * u, color: color(0x3BFF2E, alpha: 0.45))
  ctx.addPath(star)
  ctx.setFillColor(color(0x22D81B))
  ctx.fillPath()
  ctx.restoreGState()

  ctx.saveGState()
  ctx.addPath(star)
  ctx.clip()
  let gradient = CGGradient(
    colorsSpace: space,
    colors: [color(0x6FF34D), color(0x1FD414), color(0x0BA80B)] as CFArray,
    locations: [0, 0.55, 1]
  )!
  ctx.drawRadialGradient(
    gradient,
    startCenter: CGPoint(x: base.x + 30 * u, y: base.y + 40 * u), startRadius: 0,
    endCenter: base, endRadius: 190 * u,
    options: [.drawsAfterEndLocation]
  )
  ctx.restoreGState()

  ctx.restoreGState() // body clip

  let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
  return rep.representation(using: .png, properties: [:])!
}

try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
for size in [16, 32, 64, 128, 256, 512, 1024] {
  let url = outputDir.appendingPathComponent("app_icon_\(size).png")
  try render(size: size).write(to: url)
  print("wrote \(url.path)")
}
