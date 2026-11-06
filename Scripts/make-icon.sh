#!/bin/bash
# 用 SwiftUI 离屏渲染出 1024 图标，再转成 .icns。无需设计素材。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/.iconbuild"
mkdir -p "$WORK" "$ROOT/Resources"

cat > "$WORK/main.swift" <<'SWIFT'
import AppKit

let size = 1024.0
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { exit(1) }

// 圆角方形底
let inset = 44.0
let rect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let path = CGPath(roundedRect: rect, cornerWidth: 228, cornerHeight: 228, transform: nil)
ctx.saveGState()
ctx.addPath(path)
ctx.clip()

let colors = [
    NSColor(srgbRed: 0.13, green: 0.15, blue: 0.19, alpha: 1).cgColor,
    NSColor(srgbRed: 0.035, green: 0.04, blue: 0.055, alpha: 1).cgColor
] as CFArray
if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])
}

// 左上柔光
if let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                         colors: [NSColor(srgbRed: 0.91, green: 0.78, blue: 0.53, alpha: 0.30).cgColor,
                                  NSColor(srgbRed: 0.91, green: 0.78, blue: 0.53, alpha: 0).cgColor] as CFArray,
                         locations: [0, 1]) {
    ctx.drawRadialGradient(glow,
                           startCenter: CGPoint(x: size * 0.22, y: size * 0.85), startRadius: 0,
                           endCenter: CGPoint(x: size * 0.22, y: size * 0.85), endRadius: size * 0.72,
                           options: [])
}
ctx.restoreGState()

// 外描边
ctx.saveGState()
ctx.addPath(path)
ctx.setStrokeColor(NSColor(white: 1, alpha: 0.16).cgColor)
ctx.setLineWidth(3)
ctx.strokePath()
ctx.restoreGState()

// 中央：金色上升的钱币弧线 —— 一个"结算完成"的对勾 + 上升趋势
ctx.saveGState()
ctx.translateBy(x: size / 2, y: size / 2)

let gold = NSColor(srgbRed: 0.945, green: 0.815, blue: 0.588, alpha: 1)
let goldBright = NSColor(srgbRed: 0.988, green: 0.925, blue: 0.792, alpha: 1)

// 圆环
ctx.setStrokeColor(gold.withAlphaComponent(0.24).cgColor)
ctx.setLineWidth(34)
ctx.addEllipse(in: CGRect(x: -250, y: -250, width: 500, height: 500))
ctx.strokePath()

// 进度弧（约 74%），自顶部顺时针，缺口留在右上
ctx.setStrokeColor(gold.cgColor)
ctx.setLineWidth(34)
ctx.setLineCap(.round)
ctx.addArc(center: .zero, radius: 250, startAngle: .pi / 2, endAngle: .pi / 2 - .pi * 1.48, clockwise: true)
ctx.strokePath()

// 内部：先平后陡的上升曲线（曲棍球杆），寓意"今天的时间在换钱"
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.setStrokeColor(goldBright.cgColor)
ctx.setLineWidth(40)
ctx.move(to: CGPoint(x: -134, y: -74))
ctx.addCurve(to: CGPoint(x: 118, y: 92),
             control1: CGPoint(x: -40, y: -92),
             control2: CGPoint(x: 30, y: -8))
ctx.strokePath()

// 折线端点圆点
ctx.setFillColor(goldBright.cgColor)
ctx.addEllipse(in: CGRect(x: 94, y: 68, width: 48, height: 48))
ctx.fillPath()

ctx.restoreGState()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
SWIFT

echo "==> 渲染 1024 图标"
swift "$WORK/main.swift" "$WORK/icon-1024.png"

ICONSET="$WORK/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

for s in 16 32 128 256 512; do
  sips -z $s $s "$WORK/icon-1024.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  d=$((s * 2))
  sips -z $d $d "$WORK/icon-1024.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o "$ROOT/Resources/AppIcon.icns"
cp "$WORK/icon-1024.png" "$ROOT/Resources/icon-1024.png"
rm -rf "$WORK"

echo "==> 完成: Resources/AppIcon.icns"
