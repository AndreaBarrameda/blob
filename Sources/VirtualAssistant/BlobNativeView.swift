import AppKit

class BlobNativeView: NSView {
    var scale: CGFloat = 1.0
    var bobOffset: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.clear.setFill()
        dirtyRect.fill()

        let center = CGPoint(x: bounds.midX, y: bounds.midY + bobOffset)
        let radius = min(bounds.width, bounds.height) / 3 * scale

        // Draw blob
        let blobPath = NSBezierPath(ovalIn: NSRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))

        NSColor(red: 0.7, green: 0.6, blue: 0.9, alpha: 1).setFill()
        blobPath.fill()
        NSColor(red: 0.5, green: 0.4, blue: 0.8, alpha: 1).setStroke()
        blobPath.lineWidth = 2
        blobPath.stroke()

        // Draw eyes
        let eyeRadius: CGFloat = 8
        let eyeSpacing: CGFloat = 16
        let eyeY = center.y + 20

        // Left eye
        let leftEyePath = NSBezierPath(ovalIn: NSRect(
            x: center.x - eyeSpacing - eyeRadius,
            y: eyeY - eyeRadius,
            width: eyeRadius * 2,
            height: eyeRadius * 2
        ))
        NSColor.white.setFill()
        leftEyePath.fill()

        let leftPupilPath = NSBezierPath(ovalIn: NSRect(
            x: center.x - eyeSpacing - 3,
            y: eyeY - 3,
            width: 6,
            height: 6
        ))
        NSColor.black.setFill()
        leftPupilPath.fill()

        // Right eye
        let rightEyePath = NSBezierPath(ovalIn: NSRect(
            x: center.x + eyeSpacing - eyeRadius,
            y: eyeY - eyeRadius,
            width: eyeRadius * 2,
            height: eyeRadius * 2
        ))
        NSColor.white.setFill()
        rightEyePath.fill()

        let rightPupilPath = NSBezierPath(ovalIn: NSRect(
            x: center.x + eyeSpacing - 3,
            y: eyeY - 3,
            width: 6,
            height: 6
        ))
        NSColor.black.setFill()
        rightPupilPath.fill()
    }

    func startAnimations() {
        // Breathing animation
        var increasing = true
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            if increasing {
                self?.scale += 0.01
                if self?.scale ?? 1.0 >= 1.1 {
                    increasing = false
                }
            } else {
                self?.scale -= 0.01
                if self?.scale ?? 1.0 <= 0.95 {
                    increasing = true
                }
            }
            self?.needsDisplay = true
        }

        // Bobbing animation
        var bobIncreasing = true
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            if bobIncreasing {
                self?.bobOffset += 0.3
                if self?.bobOffset ?? 0 >= 10 {
                    bobIncreasing = false
                }
            } else {
                self?.bobOffset -= 0.3
                if self?.bobOffset ?? 0 <= -10 {
                    bobIncreasing = true
                }
            }
            self?.needsDisplay = true
        }
    }

    override func mouseDown(with event: NSEvent) {
        NotificationCenter.default.post(name: NSNotification.Name("BlobTapped"), object: nil)
    }
}
