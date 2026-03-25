import AppKit

class BlobNativeView: NSView {
    var scale: CGFloat = 1.0
    var bobOffset: CGFloat = 0
    var pupilOffsetX: CGFloat = 0
    var pupilOffsetY: CGFloat = 0
    var eyeBlinkScale: CGFloat = 1.0
    var mouseLocation = NSPoint.zero
    var isResponding = false

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.clear.setFill()
        dirtyRect.fill()

        let center = CGPoint(x: bounds.midX, y: bounds.midY + bobOffset)
        let radius = min(bounds.width, bounds.height) / 3 * scale

        // Draw blob with pulsing effect
        let blobPath = NSBezierPath(ovalIn: NSRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))

        // Pulse glow when responding
        if isResponding {
            NSColor(red: 0.8, green: 0.7, blue: 1.0, alpha: 0.6).setFill()
            blobPath.fill()
        }

        NSColor(red: 0.7, green: 0.6, blue: 0.9, alpha: 1).setFill()
        blobPath.fill()
        NSColor(red: 0.5, green: 0.4, blue: 0.8, alpha: 1).setStroke()
        blobPath.lineWidth = 2
        blobPath.stroke()

        // Draw eyes with blinking and following
        let eyeRadius: CGFloat = 8
        let eyeSpacing: CGFloat = 16
        let eyeY = center.y + 20

        // Calculate pupil position based on mouse follow
        let pupilRadius: CGFloat = 3 * eyeBlinkScale

        // Left eye
        let leftEyePath = NSBezierPath(ovalIn: NSRect(
            x: center.x - eyeSpacing - eyeRadius,
            y: eyeY - eyeRadius * eyeBlinkScale,
            width: eyeRadius * 2,
            height: eyeRadius * 2 * eyeBlinkScale
        ))
        NSColor.white.setFill()
        leftEyePath.fill()

        let leftPupilPath = NSBezierPath(ovalIn: NSRect(
            x: center.x - eyeSpacing - pupilRadius + pupilOffsetX,
            y: eyeY - pupilRadius + pupilOffsetY,
            width: pupilRadius * 2,
            height: pupilRadius * 2
        ))
        NSColor.black.setFill()
        leftPupilPath.fill()

        // Right eye
        let rightEyePath = NSBezierPath(ovalIn: NSRect(
            x: center.x + eyeSpacing - eyeRadius,
            y: eyeY - eyeRadius * eyeBlinkScale,
            width: eyeRadius * 2,
            height: eyeRadius * 2 * eyeBlinkScale
        ))
        NSColor.white.setFill()
        rightEyePath.fill()

        let rightPupilPath = NSBezierPath(ovalIn: NSRect(
            x: center.x + eyeSpacing - pupilRadius + pupilOffsetX,
            y: eyeY - pupilRadius + pupilOffsetY,
            width: pupilRadius * 2,
            height: pupilRadius * 2
        ))
        NSColor.black.setFill()
        rightPupilPath.fill()
    }

    override func mouseMoved(with event: NSEvent) {
        mouseLocation = event.locationInWindow
        updatePupilPosition()
    }

    private func updatePupilPosition() {
        guard let window = window else { return }
        let windowCenter = CGPoint(x: window.frame.midX, y: window.frame.midY)

        let dx = mouseLocation.x - windowCenter.x
        let dy = mouseLocation.y - windowCenter.y
        let distance = sqrt(dx * dx + dy * dy)

        if distance > 0 {
            let maxOffset: CGFloat = 3
            pupilOffsetX = (dx / distance) * maxOffset
            pupilOffsetY = (dy / distance) * maxOffset
            needsDisplay = true
        }
    }

    func startAnimations() {
        // Breathing animation with pulsing
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.scale = 1.0 + sin(Date().timeIntervalSince1970) * 0.08
            self?.needsDisplay = true
        }

        // Bobbing animation
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.bobOffset = sin(Date().timeIntervalSince1970 * 0.5) * 8
            self?.needsDisplay = true
        }

        // Blinking animation - random intervals
        Timer.scheduledTimer(withTimeInterval: Double.random(in: 3...7), repeats: true) { [weak self] _ in
            self?.blink()
        }

        // Enable mouse tracking at window level
        DispatchQueue.main.async { [weak self] in
            self?.window?.acceptsMouseMovedEvents = true

            // Set up tracking area with full bounds
            if let strongSelf = self {
                let trackingArea = NSTrackingArea(
                    rect: strongSelf.bounds,
                    options: [.mouseMoved, .activeAlways, .inVisibleRect],
                    owner: strongSelf,
                    userInfo: nil
                )
                strongSelf.addTrackingArea(trackingArea)
            }
        }
    }

    private func blink() {
        var progress: CGFloat = 0
        Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] timer in
            progress += 0.2
            if progress < 1.0 {
                self?.eyeBlinkScale = 1.0 - progress
            } else if progress < 2.0 {
                self?.eyeBlinkScale = progress - 1.0
            } else {
                self?.eyeBlinkScale = 1.0
                timer.invalidate()
            }
            self?.needsDisplay = true
        }
    }

    func respondingAnimation() {
        isResponding = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isResponding = false
            self?.needsDisplay = true
        }
    }

    override func mouseDown(with event: NSEvent) {
        NotificationCenter.default.post(name: NSNotification.Name("BlobTapped"), object: nil)
    }
}
