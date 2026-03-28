import AppKit

enum BlobMood: String, Codable {
    case curious    // 😳 wide eyes, blue glow
    case thoughtful // 🤔 narrow eyes, purple glow
    case playful    // 😄 happy eyes, pink glow
    case alert      // ⚡ very wide eyes, red glow
    case angry      // 😠 narrow angry eyes, dark red glow
    case annoyed    // 🙄 flat, irritated eyes, amber glow
    case offended   // 😤 indignant eyes, rose glow
    case afraid     // 😨 very wide eyes, pale glow
    case delighted  // ✨ bright, excited eyes, gold glow
    case content    // 🫧 normal, soft glow
    case longing    // 💔 half-closed eyes, indigo glow — melancholy, aching
    case proud      // 👑 slightly wide eyes, warm gold glow — satisfied, accomplished
    case bored      // 😑 flat droopy eyes, grey-blue glow — understimulated, restless
    case ashamed    // 😳 tight eyes, muted rose glow — withdrawn, embarrassed
    case wondering  // 🌌 very wide + pulse, deep violet glow — awestruck, philosophical
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
    var currentMood: BlobMood { mood }  // Public accessor for reading current mood
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
        case .afraid:
            targetEyeWiden = 1.65  // Panic wide
        case .angry:
            targetEyeWiden = 0.7  // Narrow angry eyes
        case .annoyed:
            targetEyeWiden = 0.82  // Flat irritated eyes
        case .offended:
            targetEyeWiden = 0.9  // Slightly narrowed, indignant
        case .thoughtful:
            targetEyeWiden = 0.8  // Narrow
        case .playful, .content, .delighted:
            targetEyeWiden = 1.0  // Normal
        case .longing:
            targetEyeWiden = 0.6  // Half-closed, melancholy
        case .proud:
            targetEyeWiden = 1.1  // Slightly wide, satisfied
        case .bored:
            targetEyeWiden = 0.55  // Flat, droopy
        case .ashamed:
            targetEyeWiden = 0.65  // Tight, withdrawn
        case .wondering:
            targetEyeWiden = 1.45  // Very wide, awestruck
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
                NSColor(red: 0.22, green: 0.82, blue: 1.0, alpha: 0.7),
                NSColor(red: 0.62, green: 0.9, blue: 1.0, alpha: 1),
                NSColor(red: 0.12, green: 0.62, blue: 0.9, alpha: 1)
            )
        case .thoughtful:
            return (
                NSColor(red: 0.55, green: 0.45, blue: 1.0, alpha: 0.65),
                NSColor(red: 0.78, green: 0.75, blue: 0.98, alpha: 1),
                NSColor(red: 0.42, green: 0.3, blue: 0.82, alpha: 1)
            )
        case .playful:
            return (
                NSColor(red: 1.0, green: 0.48, blue: 0.78, alpha: 0.7),
                NSColor(red: 1.0, green: 0.78, blue: 0.9, alpha: 1),
                NSColor(red: 0.9, green: 0.28, blue: 0.64, alpha: 1)
            )
        case .alert:
            return (
                NSColor(red: 1.0, green: 0.2, blue: 0.16, alpha: 0.72),
                NSColor(red: 1.0, green: 0.66, blue: 0.5, alpha: 1),
                NSColor(red: 0.84, green: 0.16, blue: 0.12, alpha: 1)
            )
        case .angry:
            return (
                NSColor(red: 0.72, green: 0.05, blue: 0.08, alpha: 0.78),
                NSColor(red: 0.93, green: 0.34, blue: 0.3, alpha: 1),
                NSColor(red: 0.52, green: 0.04, blue: 0.06, alpha: 1)
            )
        case .annoyed:
            return (
                NSColor(red: 0.98, green: 0.62, blue: 0.12, alpha: 0.68),
                NSColor(red: 1.0, green: 0.84, blue: 0.52, alpha: 1),
                NSColor(red: 0.78, green: 0.46, blue: 0.08, alpha: 1)
            )
        case .offended:
            return (
                NSColor(red: 1.0, green: 0.22, blue: 0.54, alpha: 0.72),
                NSColor(red: 1.0, green: 0.7, blue: 0.82, alpha: 1),
                NSColor(red: 0.8, green: 0.12, blue: 0.4, alpha: 1)
            )
        case .afraid:
            return (
                NSColor(red: 0.62, green: 0.86, blue: 1.0, alpha: 0.58),
                NSColor(red: 0.9, green: 0.97, blue: 1.0, alpha: 1),
                NSColor(red: 0.4, green: 0.64, blue: 0.82, alpha: 1)
            )
        case .delighted:
            return (
                NSColor(red: 1.0, green: 0.82, blue: 0.12, alpha: 0.74),
                NSColor(red: 1.0, green: 0.94, blue: 0.56, alpha: 1),
                NSColor(red: 0.88, green: 0.62, blue: 0.04, alpha: 1)
            )
        case .content:
            return (
                NSColor(red: 0.44, green: 0.92, blue: 0.72, alpha: 0.58),
                NSColor(red: 0.72, green: 0.95, blue: 0.84, alpha: 1),
                NSColor(red: 0.26, green: 0.7, blue: 0.52, alpha: 1)
            )
        case .longing:
            return (
                NSColor(red: 0.48, green: 0.38, blue: 0.82, alpha: 0.62),
                NSColor(red: 0.82, green: 0.76, blue: 0.95, alpha: 1),
                NSColor(red: 0.38, green: 0.22, blue: 0.7, alpha: 1)
            )
        case .proud:
            return (
                NSColor(red: 1.0, green: 0.84, blue: 0.28, alpha: 0.76),
                NSColor(red: 1.0, green: 0.92, blue: 0.64, alpha: 1),
                NSColor(red: 0.92, green: 0.72, blue: 0.12, alpha: 1)
            )
        case .bored:
            return (
                NSColor(red: 0.38, green: 0.54, blue: 0.72, alpha: 0.48),
                NSColor(red: 0.68, green: 0.76, blue: 0.82, alpha: 1),
                NSColor(red: 0.28, green: 0.42, blue: 0.58, alpha: 1)
            )
        case .ashamed:
            return (
                NSColor(red: 0.82, green: 0.54, blue: 0.68, alpha: 0.56),
                NSColor(red: 0.92, green: 0.78, blue: 0.84, alpha: 1),
                NSColor(red: 0.68, green: 0.38, blue: 0.54, alpha: 1)
            )
        case .wondering:
            return (
                NSColor(red: 0.52, green: 0.38, blue: 0.92, alpha: 0.68),
                NSColor(red: 0.84, green: 0.78, blue: 0.98, alpha: 1),
                NSColor(red: 0.42, green: 0.22, blue: 0.88, alpha: 1)
            )
        }
    }

    override func mouseDown(with event: NSEvent) {
        NotificationCenter.default.post(name: NSNotification.Name("BlobTapped"), object: nil)
    }
}
