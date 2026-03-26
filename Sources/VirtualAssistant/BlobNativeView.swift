import AppKit

enum BlobMood: String, Codable {
    case curious    // 😳 wide eyes, blue glow
    case thoughtful // 🤔 narrow eyes, purple glow
    case playful    // 😄 happy eyes, pink glow
    case alert      // ⚡ very wide eyes, red glow
    case angry      // 😠 narrow angry eyes, dark red glow
    case content    // 🫧 normal, soft glow
}

class BlobNativeView: NSView {
    var scale: CGFloat = 1.0
    var bobOffset: CGFloat = 0
    var pupilOffsetX: CGFloat = 0
    var pupilOffsetY: CGFloat = 0
    var eyeBlinkScale: CGFloat = 1.0
    var mouseLocation = NSPoint.zero
    var isResponding = false
    var mood: BlobMood = .content
    var eyeWidenFactor: CGFloat = 1.0  // 1.4 = wide (curious), 0.85 = narrow (thoughtful)

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

        // Mood-based glow
        let (glowColor, bodyColor, borderColor) = moodColors()

        // Draw mood-based glow aura (concentric circles)
        let glowRadii: [CGFloat] = [radius * 1.6, radius * 1.35, radius * 1.1]
        let glowAlphas: [CGFloat] = [0.15, 0.25, 0.35]

        for (index, glowRadius) in glowRadii.enumerated() {
            let glowPath = NSBezierPath(ovalIn: NSRect(
                x: center.x - glowRadius,
                y: center.y - glowRadius,
                width: glowRadius * 2,
                height: glowRadius * 2
            ))
            glowColor.withAlphaComponent(glowAlphas[index]).setFill()
            glowPath.fill()
        }

        if isResponding {
            glowColor.withAlphaComponent(0.5).setFill()
            blobPath.fill()
        }

        bodyColor.setFill()
        blobPath.fill()
        borderColor.setStroke()
        blobPath.lineWidth = 2
        blobPath.stroke()

        // Draw eyes with blinking, mood expression, and following
        let baseEyeRadius: CGFloat = 8 * eyeWidenFactor
        let eyeSpacing: CGFloat = 16
        let eyeY = center.y + 20

        // Calculate pupil position based on mouse follow
        let pupilRadius: CGFloat = (3 * eyeBlinkScale) + (eyeWidenFactor - 1.0) * 2

        // Left eye
        let leftEyePath = NSBezierPath(ovalIn: NSRect(
            x: center.x - eyeSpacing - baseEyeRadius,
            y: eyeY - baseEyeRadius * eyeBlinkScale,
            width: baseEyeRadius * 2,
            height: baseEyeRadius * 2 * eyeBlinkScale
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
            x: center.x + eyeSpacing - baseEyeRadius,
            y: eyeY - baseEyeRadius * eyeBlinkScale,
            width: baseEyeRadius * 2,
            height: baseEyeRadius * 2 * eyeBlinkScale
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
            setNeedsDisplay(bounds)
        }
    }

    func startAnimations() {
        // Breathing animation with pulsing
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.scale = 1.0 + sin(Date().timeIntervalSince1970) * 0.08
            self.setNeedsDisplay(self.bounds)
        }

        // Bobbing animation
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.bobOffset = sin(Date().timeIntervalSince1970 * 0.5) * 8
            self.setNeedsDisplay(self.bounds)
        }

        // Blinking animation - random intervals
        Timer.scheduledTimer(withTimeInterval: Double.random(in: 3...7), repeats: true) { [weak self] _ in
            self?.blink()
        }

        // Enable mouse tracking
        self.window?.acceptsMouseMovedEvents = true

        let trackingArea = NSTrackingArea(
            rect: self.bounds,
            options: [.mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        self.addTrackingArea(trackingArea)
    }

    private func blink() {
        var progress: CGFloat = 0
        Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            progress += 0.2
            if progress < 1.0 {
                self.eyeBlinkScale = 1.0 - progress
            } else if progress < 2.0 {
                self.eyeBlinkScale = progress - 1.0
            } else {
                self.eyeBlinkScale = 1.0
                timer.invalidate()
            }
            self.setNeedsDisplay(self.bounds)
        }
    }

    func respondingAnimation() {
        isResponding = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isResponding = false
            self?.needsDisplay = true
        }
    }

    func setMood(_ newMood: BlobMood, animated: Bool = true) {
        let targetEyeWiden: CGFloat
        switch newMood {
        case .curious:
            targetEyeWiden = 1.4  // Wide eyes
        case .alert:
            targetEyeWiden = 1.5  // Very wide
        case .angry:
            targetEyeWiden = 0.7  // Narrow angry eyes
        case .thoughtful:
            targetEyeWiden = 0.8  // Narrow
        case .playful, .content:
            targetEyeWiden = 1.0  // Normal
        }

        if animated {
            let steps = 10
            var step = 0
            Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                step += 1
                let progress = CGFloat(step) / CGFloat(steps)
                self.eyeWidenFactor = self.eyeWidenFactor + (targetEyeWiden - self.eyeWidenFactor) * progress / CGFloat(steps)
                self.mood = newMood
                self.setNeedsDisplay(self.bounds)

                if step >= steps {
                    timer.invalidate()
                    self.eyeWidenFactor = targetEyeWiden
                }
            }
        } else {
            mood = newMood
            eyeWidenFactor = targetEyeWiden
            setNeedsDisplay(bounds)
        }
    }

    private func moodColors() -> (glow: NSColor, body: NSColor, border: NSColor) {
        switch mood {
        case .curious:
            return (
                NSColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 0.6),  // Cyan glow
                NSColor(red: 0.7, green: 0.8, blue: 1.0, alpha: 1),    // Light blue body
                NSColor(red: 0.4, green: 0.6, blue: 0.9, alpha: 1)     // Blue border
            )
        case .thoughtful:
            return (
                NSColor(red: 0.9, green: 0.6, blue: 1.0, alpha: 0.6),  // Purple glow
                NSColor(red: 0.8, green: 0.7, blue: 0.95, alpha: 1),   // Soft purple body
                NSColor(red: 0.6, green: 0.4, blue: 0.85, alpha: 1)    // Purple border
            )
        case .playful:
            return (
                NSColor(red: 1.0, green: 0.7, blue: 0.9, alpha: 0.6),  // Pink glow
                NSColor(red: 1.0, green: 0.8, blue: 0.95, alpha: 1),   // Light pink body
                NSColor(red: 0.9, green: 0.5, blue: 0.8, alpha: 1)     // Pink border
            )
        case .alert:
            return (
                NSColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 0.6),  // Red glow
                NSColor(red: 1.0, green: 0.7, blue: 0.7, alpha: 1),    // Light red body
                NSColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1)     // Red border
            )
        case .angry:
            return (
                NSColor(red: 0.95, green: 0.3, blue: 0.3, alpha: 0.6),  // Dark red glow
                NSColor(red: 1.0, green: 0.6, blue: 0.6, alpha: 1),     // Red body
                NSColor(red: 0.85, green: 0.2, blue: 0.2, alpha: 1)     // Dark red border
            )
        case .content:
            return (
                NSColor(red: 0.8, green: 0.7, blue: 1.0, alpha: 0.6),  // Soft purple glow
                NSColor(red: 0.7, green: 0.6, blue: 0.9, alpha: 1),    // Normal purple body
                NSColor(red: 0.5, green: 0.4, blue: 0.8, alpha: 1)     // Normal border
            )
        }
    }

    override func mouseDown(with event: NSEvent) {
        NotificationCenter.default.post(name: NSNotification.Name("BlobTapped"), object: nil)
    }
}
