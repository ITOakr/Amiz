// アプリアイコンを描くスクリプト（macOS の CoreGraphics だけで動く）。
// 使い方：swift docs/icon/make-icon.swift <出力フォルダ>
// 記号図をモチーフにした簡素な図案：わの作り目の輪、1段目の細編み6目、2段目の12目（放射状の×）。
// ライト（生成りの地にこげ茶）、ダーク（こげ茶の地に生成り）、ティント（白地に黒。iOS が色を付ける）の3枚を出す。
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let size = 1024.0
let output = CommandLine.arguments.dropFirst().first ?? "."

struct Palette {
    let background: CGColor
    let ink: CGColor
    let accent: CGColor
}

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let palettes: [(name: String, palette: Palette)] = [
    ("AppIcon.png", Palette(background: color(0xF3E9DA), ink: color(0x5A3A22), accent: color(0xC98A6B))),
    ("AppIcon-dark.png", Palette(background: color(0x3B2A1E), ink: color(0xF3E9DA), accent: color(0xE0A88A))),
    ("AppIcon-tinted.png", Palette(background: color(0xFFFFFF), ink: color(0x000000), accent: color(0x000000))),
]

/// ×（細編み）を根元から頭へ向けて描く
func drawCross(_ context: CGContext, root: CGPoint, head: CGPoint, arm: CGFloat, width: CGFloat) {
    let mid = CGPoint(x: (root.x + head.x) / 2, y: (root.y + head.y) / 2)
    let dx = head.x - root.x, dy = head.y - root.y
    let length = max(1, hypot(dx, dy))
    let d = CGPoint(x: dx / length, y: dy / length)
    let n = CGPoint(x: -d.y, y: d.x)
    context.setLineWidth(width)
    context.setLineCap(.round)
    for sign in [1.0, -1.0] {
        // 線分に対して45度の腕
        let a = CGPoint(x: (d.x + n.x * sign) / 1.4142 * arm, y: (d.y + n.y * sign) / 1.4142 * arm)
        context.move(to: CGPoint(x: mid.x - a.x, y: mid.y - a.y))
        context.addLine(to: CGPoint(x: mid.x + a.x, y: mid.y + a.y))
    }
    context.strokePath()
}

for (name, palette) in palettes {
    guard let context = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        fatalError("context")
    }
    context.setFillColor(palette.background)
    context.fill(CGRect(x: 0, y: 0, width: size, height: size))

    let center = CGPoint(x: size / 2, y: size / 2)
    // わの作り目の輪
    context.setStrokeColor(palette.ink)
    context.setLineWidth(22)
    context.strokeEllipse(in: CGRect(x: center.x - 70, y: center.y - 70, width: 140, height: 140))

    // 1段目：細編み6目（放射状の×）
    let inner: CGFloat = 70, outer1: CGFloat = 230
    for index in 0..<6 {
        let angle = CGFloat(index) / 6 * .pi * 2 + .pi / 6
        let root = CGPoint(x: center.x + cos(angle) * (inner + 14), y: center.y + sin(angle) * (inner + 14))
        let head = CGPoint(x: center.x + cos(angle) * outer1, y: center.y + sin(angle) * outer1)
        drawCross(context, root: root, head: head, arm: 52, width: 26)
    }
    // 2段目：全目に増し目で12目（放射状の×を等間隔に）。1段目より少し細く、差し色で
    context.setStrokeColor(palette.accent)
    let inner2: CGFloat = 275, outer2: CGFloat = 400
    for index in 0..<12 {
        let angle = CGFloat(index) / 12 * .pi * 2 + .pi / 12
        let root = CGPoint(x: center.x + cos(angle) * inner2, y: center.y + sin(angle) * inner2)
        let head = CGPoint(x: center.x + cos(angle) * outer2, y: center.y + sin(angle) * outer2)
        drawCross(context, root: root, head: head, arm: 46, width: 22)
    }

    let image = context.makeImage()!
    let url = URL(fileURLWithPath: output).appendingPathComponent(name)
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
    print("wrote \(url.path)")
}
