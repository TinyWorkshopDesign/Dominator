import CoreGraphics
import ImageIO
import Foundation
import UniformTypeIdentifiers

let S = 1024
let cs = CGColorSpaceCreateDeviceRGB()
let black = CGColor(colorSpace: cs, components: [0.07, 0.07, 0.08, 1])!
let white = CGColor(colorSpace: cs, components: [1.0, 1.0, 1.0, 1])!

func ctxNew() -> CGContext {
    CGContext(data: nil, width: S, height: S, bitsPerComponent: 8, bytesPerRow: 0,
              space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

/// Tre punti bianchi a "L": due in alto (sinistra/destra), uno in basso a sinistra.
func drawDots(_ c: CGContext, in rect: CGRect) {
    let r = rect.width * 0.155
    let m = rect.width * 0.27            // distanza dei centri dai bordi
    let centers = [
        CGPoint(x: rect.minX + m, y: rect.maxY - m),   // alto sinistra
        CGPoint(x: rect.maxX - m, y: rect.maxY - m),   // alto destra
        CGPoint(x: rect.minX + m, y: rect.minY + m)    // basso sinistra
    ]
    c.setFillColor(white)
    for p in centers {
        c.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
    }
}

func render(fullBleed: Bool) -> CGImage {
    let c = ctxNew()
    let canvas = CGRect(x: 0, y: 0, width: S, height: S)
    c.saveGState()
    let content: CGRect
    if fullBleed {
        // iOS/iPadOS: nero a tutto schermo (il sistema arrotonda gli angoli)
        content = canvas
        c.setFillColor(black)
        c.fill(canvas)
    } else {
        // macOS: squircle nero con margine trasparente, nessuno sfondo
        let inset = CGFloat(S) * 0.094
        content = canvas.insetBy(dx: inset, dy: inset)
        let r = content.width * 0.2247
        c.addPath(CGPath(roundedRect: content, cornerWidth: r, cornerHeight: r, transform: nil))
        c.clip()
        c.setFillColor(black)
        c.fill(content)
    }
    let faceInset = content.width * (fullBleed ? 0.13 : 0.10)
    drawDots(c, in: content.insetBy(dx: faceInset, dy: faceInset))
    c.restoreGState()
    return c.makeImage()!
}

func writePNG(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path) as CFURL
    let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

writePNG(render(fullBleed: true), to: "/tmp/icon_ios_1024.png")
writePNG(render(fullBleed: false), to: "/tmp/icon_mac_1024.png")
print("Icone master generate.")
