import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()

let cream = NSColor(srgbRed: 0.957, green: 0.941, blue: 0.910, alpha: 1)
let charcoal = NSColor(srgbRed: 0.145, green: 0.145, blue: 0.145, alpha: 1)
let orange = NSColor(srgbRed: 1.0, green: 0.322, blue: 0.106, alpha: 1)

// Cream paper tile
let tile = NSBezierPath(roundedRect: NSRect(x: 28, y: 28, width: size - 56, height: size - 56), xRadius: 220, yRadius: 220)
cream.setFill()
tile.fill()

// Charcoal specimen square
let markRect = NSRect(x: 262, y: 262, width: 500, height: 500)
let specimen = NSBezierPath(roundedRect: markRect, xRadius: 104, yRadius: 104)
charcoal.setFill()
specimen.fill()

// Pilcrow: a full-height mast, an orange bowl, and the right leg of the mark.
let glyphW: CGFloat = 280
let glyphH: CGFloat = 406
let box = NSRect(x: (size - glyphW) / 2, y: (size - glyphH) / 2, width: glyphW, height: glyphH)
let stroke = glyphW * 0.255

cream.setFill()
NSBezierPath(
    roundedRect: NSRect(x: box.minX, y: box.minY, width: stroke, height: box.height),
    xRadius: stroke * 0.35,
    yRadius: stroke * 0.35
).fill()

orange.setFill()
NSBezierPath(
    roundedRect: NSRect(
        x: box.maxX - stroke,
        y: box.minY,
        width: stroke,
        height: box.height * 0.68
    ),
    xRadius: stroke * 0.35,
    yRadius: stroke * 0.35
).fill()

let bowl = NSRect(
    x: box.minX + stroke,
    y: box.minY + box.height * 0.5,
    width: box.width - stroke,
    height: box.height * 0.5
).insetBy(dx: stroke / 2, dy: stroke / 2)
let bowlPath = NSBezierPath(
    roundedRect: bowl,
    xRadius: glyphW * 0.2 - stroke / 2,
    yRadius: glyphW * 0.2 - stroke / 2
)
bowlPath.lineWidth = stroke
orange.setStroke()
bowlPath.stroke()

// Tiny maker's annotation
let rule = NSBezierPath()
rule.lineWidth = 3
rule.move(to: NSPoint(x: 92, y: 92))
rule.line(to: NSPoint(x: 176, y: 92))
orange.setStroke()
rule.stroke()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("Could not render icon")
}
let url = URL(fileURLWithPath: CommandLine.arguments[1])
try png.write(to: url)
print(url.path)
