import AppKit

// ZQuota TouchBar 电量条 BTT 版渲染器
// 视觉规格 1:1 移植自 ZQuota/Sources/SegmentedBatteryBar.swift：
//   外框 175×11 inset(1,1) 胶囊描边；段区 inset(5,3)；10 段、段距 2、圆角 2
//   颜色 ≤20% 红 / ≤45% 黄 / 其余荧光绿(0.56,1.0,0.12)；未亮段暗灰
// 产物为双行合成图（条1在上、条2在下），供 BTT shell script widget 的 icon_path 使用
//
// 用法：
//   swift render-bars.swift one <p1> <p2> <out.png> [row1Y] [row2Y]   单张（懒渲染用）
//   swift render-bars.swift all <dir> [row1Y] [row2Y]                全量 0-100 步进 5 共 441 张
//   swift render-bars.swift refresh <out.png>                        刷新图标(SF Symbol)
// row1Y/row2Y：两条中心在 30pt 高画布上的 y 坐标（适配 BTT 双行文字行高），默认 23/8

// 输出按 TouchBar 2x 屏的像素密度渲染（rep.size 175×30 / 像素 350×60）

func colorFor(percent: Double) -> NSColor {
    if percent <= 20 { return NSColor(red: 1.0, green: 69.0 / 255, blue: 58.0 / 255, alpha: 1) }
    if percent <= 45 { return NSColor(red: 1.0, green: 214.0 / 255, blue: 10.0 / 255, alpha: 1) }
    return NSColor(calibratedRed: 0.56, green: 1.0, blue: 0.12, alpha: 1)
}

// ZQuota 同款：ceil(p/100*10) 段亮起
func segmentsFor(percent: Double) -> Int {
    Int(ceil(max(0, min(100, percent)) / 100 * 10))
}

func drawBatteryBar(_ ctx: CGContext, rect: CGRect, percent: Double, dimmed: Bool) {
    let barW: CGFloat = 175, barH: CGFloat = 11
    let outer = rect.insetBy(dx: (rect.width - barW) / 2, dy: (rect.height - barH) / 2)
        .insetBy(dx: 1, dy: 1) // bounds.insetBy(1,1)
    let outerPath = CGPath(roundedRect: outer, cornerWidth: outer.height / 2, cornerHeight: outer.height / 2, transform: nil)
    ctx.addPath(outerPath)
    ctx.setStrokeColor(NSColor(red: 160.0 / 255, green: 160.0 / 255, blue: 165.0 / 255, alpha: 0.65).cgColor)
    ctx.setLineWidth(1.3)
    ctx.strokePath()

    let seg = outer.insetBy(dx: 5, dy: 3)
    let spacing: CGFloat = 2, count = 10
    let segW = (seg.width - CGFloat(count - 1) * spacing) / CGFloat(count)
    let filled = segmentsFor(percent: percent)
    let fill = colorFor(percent: percent)

    for i in 0..<count {
        let x = seg.minX + CGFloat(i) * (segW + spacing)
        let r = CGRect(x: x, y: seg.minY, width: segW, height: seg.height)
        let p = CGPath(roundedRect: r, cornerWidth: 2, cornerHeight: 2, transform: nil)
        ctx.addPath(p)
        ctx.setFillColor((!dimmed && i < filled ? fill : NSColor(red: 56.0 / 255, green: 56.0 / 255, blue: 58.0 / 255, alpha: 1)).cgColor)
        ctx.fillPath()
    }
}

// rowY 实测语义：距画布底部（pt）——row1Y=23 渲染在上排（中心距顶 7.75pt）、row2Y=8 在下排，
// 恰好匹配 BTT 双行文本行 1/行 2 的垂直中心
func renderComboFlipped(p1: Double, p2: Double, out: String, row1Y: CGFloat, row2Y: CGFloat) {
    let W: CGFloat = 175, H: CGFloat = 30, pxScale: CGFloat = 2
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W * pxScale), pixelsHigh: Int(H * pxScale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: W, height: H)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    // 上下文已按 rep.size(175×30) 与像素(350×60) 之比自带 2x 缩放，这里只翻转到 flipped 语义
    ctx.translateBy(x: 0, y: H)
    ctx.scaleBy(x: 1, y: -1)

    // rowY 语义：条中心距画布顶部（pt）；实测本上下文 rect y 越大越靠上，故取补
    for (p, rowY) in [(p1, row1Y), (p2, row2Y)] {
        drawBatteryBar(ctx, rect: CGRect(x: 0, y: H - rowY - 5.5, width: 175, height: 11), percent: p, dimmed: false)
    }
    NSGraphicsContext.restoreGraphicsState()

    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: out))
}

func renderRefreshIcon(out: String) {
    guard let symbol = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)?
        .withSymbolConfiguration(.init(pointSize: 13, weight: .medium)) else {
        fputs("SF Symbol 不可用\n", stderr); exit(1)
    }
    let size = NSSize(width: 30, height: 30)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 60, pixelsHigh: 60,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor.labelColor.set()
    symbol.draw(in: NSRect(origin: .zero, size: size), from: NSRect(origin: .zero, size: symbol.size), operation: .sourceOver, fraction: 1, respectFlipped: false, hints: [.interpolation: NSImageInterpolation.high])
    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: out))
}

let args = CommandLine.arguments
guard args.count >= 2 else { fputs("参数不足\n", stderr); exit(1) }

switch args[1] {
case "one":
    guard args.count >= 5 else { fputs("用法: one p1 p2 out.png [row1Y] [row2Y]\n", stderr); exit(1) }
    renderComboFlipped(p1: Double(args[2])!, p2: Double(args[3])!, out: args[4],
                       row1Y: args.count > 5 ? CGFloat(Double(args[5])!) : 23,
                       row2Y: args.count > 6 ? CGFloat(Double(args[6])!) : 8)
case "all":
    guard args.count >= 3 else { fputs("用法: all <dir> [row1Y] [row2Y]\n", stderr); exit(1) }
    let dir = args[2]
    let r1 = args.count > 3 ? CGFloat(Double(args[3])!) : 23
    let r2 = args.count > 4 ? CGFloat(Double(args[4])!) : 8
    for p1 in stride(from: 0, through: 100, by: 5) {
        for p2 in stride(from: 0, through: 100, by: 5) {
            renderComboFlipped(p1: Double(p1), p2: Double(p2), out: "\(dir)/bar_\(p1)_\(p2).png", row1Y: r1, row2Y: r2)
        }
    }
    let count: Int = (100 / 5 + 1) * (100 / 5 + 1)
    print("已渲染 \(count) 张到 \(dir)")
case "refresh":
    guard args.count >= 3 else { fputs("用法: refresh <out.png>\n", stderr); exit(1) }
    renderRefreshIcon(out: args[2])
default:
    fputs("未知子命令 \(args[1])\n", stderr); exit(1)
}
