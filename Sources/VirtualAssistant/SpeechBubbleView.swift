import AppKit

class SpeechBubbleWindow: NSWindow {
    init(text: String, originPoint: NSPoint) {
        let bubbleView = SpeechBubbleView(text: text)

        // Calculate size based on text with multi-line support
        let font = NSFont.systemFont(ofSize: 12)
        let maxWidth: CGFloat = 300
        let boundingRect = (text as NSString).boundingRect(
            with: CGSize(width: maxWidth - 30, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        )
        let width = min(max(ceil(boundingRect.width) + 30, 80), maxWidth)
        let height = ceil(boundingRect.height) + 30

        // Position bubble above blob with good spacing
        // Blob is 120x120, so place bubble well above it
        let blobCenterX = originPoint.x + 60
        let bubbleX = blobCenterX - width / 2
        let bubbleY = originPoint.y + 160  // 120 (blob height) + 40px gap for full visibility

        super.init(
            contentRect: NSRect(x: bubbleX, y: bubbleY, width: width, height: height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.contentView = bubbleView
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue)
        self.hasShadow = false
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SpeechBubbleView: NSView {
    let text: String

    init(text: String) {
        self.text = text
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw bubble background
        let bubblePath = NSBezierPath(roundedRect: bounds.insetBy(dx: 5, dy: 5), xRadius: 10, yRadius: 10)
        NSColor(red: 0.95, green: 0.95, blue: 1.0, alpha: 0.95).setFill()
        bubblePath.fill()

        // Draw border
        NSColor(red: 0.7, green: 0.6, blue: 0.9, alpha: 0.8).setStroke()
        bubblePath.lineWidth = 1.5
        bubblePath.stroke()

        // Draw tail pointing down
        let tailPath = NSBezierPath()
        let tailX = bounds.midX
        let tailY = bounds.minY - 8
        tailPath.move(to: NSPoint(x: tailX - 8, y: bounds.minY))
        tailPath.line(to: NSPoint(x: tailX + 8, y: bounds.minY))
        tailPath.line(to: NSPoint(x: tailX, y: tailY))
        tailPath.close()

        NSColor(red: 0.95, green: 0.95, blue: 1.0, alpha: 0.95).setFill()
        tailPath.fill()
        NSColor(red: 0.7, green: 0.6, blue: 0.9, alpha: 0.8).setStroke()
        tailPath.lineWidth = 1.5
        tailPath.stroke()

        // Draw text
        let textRect = bounds.insetBy(dx: 10, dy: 8)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.black,
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                return style
            }()
        ]

        let attributedText = NSAttributedString(string: text, attributes: attributes)
        attributedText.draw(in: textRect)
    }
}
