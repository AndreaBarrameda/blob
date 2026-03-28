import AppKit

enum BlobMood: String, Codable {
    case curious
    case thoughtful
    case playful
    case alert
    case angry
    case annoyed
    case offended
    case afraid
    case delighted
    case content
}

class BlobNativeView: NSView {
    // Animation state
    var bobOffset: CGFloat = 0
    var scaleX: CGFloat = 1.0
    var scaleY: CGFloat = 1.0
    var pupilOffsetX: CGFloat = 0
    var pupilOffsetY: CGFloat = 0
    var eyeBlinkScale: CGFloat = 1.0
    var mouseLocation = NSPoint.zero
    var isResponding = false
    var mood: BlobMood = .content
    var currentMood: BlobMood { mood }
    var eyeWidenFactor: CGFloat = 1.0

    // Smooth pupil tracking
    private var targetPupilOffsetX: CGFloat = 0
    private var targetPupilOffsetY: CGFloat = 0

    // Micro-movement state
    private var animationTime: CFTimeInterval = 0
    private var idleOffsetX: CGFloat = 0
    private var idleOffsetY: CGFloat = 0

    // Organic blob shape constants
    private let vertexCount = 64
    private let waveComponents: [(freq: CGFloat, amp: CGFloat, phase: CGFloat, speed: CGFloat)] = [
        (3, 0.035, 0.0, 1.0),
        (5, 0.020, 1.3, 0.7),
        (7, 0.012, 2.7, 1.3),
    ]

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.clear.setFill()
        dirtyRect.fill()

        let time = animationTime
        let center = CGPoint(x: bounds.midX + idleOffsetX, y: bounds.midY + bobOffset + idleOffsetY)
        let baseRadius = min(bounds.width, bounds.height) / 4.5
        let radiusX = baseRadius * scaleX
        let radiusY = baseRadius * scaleY

        let (glowColor, bodyColor, borderColor) = moodColors()

        // Glow aura — 8 organic rings fading outward, pulsing with breath
        let breathFactor = (scaleX + scaleY) / 2.0 - 1.0  // positive when breathing in
        let glowSteps = 8
        for i in 0..<glowSteps {
            let t = CGFloat(i) / CGFloat(glowSteps - 1)
            let glowScale = 1.05 + t * 0.6
            let breathBoost: CGFloat = 1.0 + max(breathFactor, 0) * 0.3
            let grx = radiusX * glowScale * breathBoost
            let gry = radiusY * glowScale * breathBoost
            let alpha = 0.30 * (1.0 - t)
            let glowPath = blobBodyPath(center: center, radiusX: grx, radiusY: gry, time: time)
            glowColor.withAlphaComponent(alpha).setFill()
            glowPath.fill()
        }

        // Body
        let bodyPath = blobBodyPath(center: center, radiusX: radiusX, radiusY: radiusY, time: time)

        if isResponding {
            glowColor.withAlphaComponent(0.5).setFill()
            bodyPath.fill()
        }

        bodyColor.setFill()
        bodyPath.fill()
        borderColor.setStroke()
        bodyPath.lineWidth = 2
        bodyPath.stroke()

        // Eyes
        drawEyes(center: center, borderColor: borderColor)

        // Mouth
        drawMouth(center: center, borderColor: borderColor)
    }

    // MARK: - Organic Body Path

    private func blobBodyPath(center: CGPoint, radiusX: CGFloat, radiusY: CGFloat, time: CFTimeInterval) -> NSBezierPath {
        let n = vertexCount
        var points = [CGPoint]()

        for i in 0..<n {
            let angle = 2.0 * .pi * CGFloat(i) / CGFloat(n)
            var displacement: CGFloat = 0
            for w in waveComponents {
                displacement += w.amp * sin(angle * w.freq + CGFloat(time) * w.speed + w.phase)
            }
            let rx = radiusX * (1.0 + displacement)
            let ry = radiusY * (1.0 + displacement)
            let x = center.x + rx * cos(angle)
            let y = center.y + ry * sin(angle)
            points.append(CGPoint(x: x, y: y))
        }

        // Build smooth closed path via Catmull-Rom to cubic Bezier conversion
        let path = NSBezierPath()
        let tension: CGFloat = 6.0

        for i in 0..<n {
            let p0 = points[(i - 1 + n) % n]
            let p1 = points[i]
            let p2 = points[(i + 1) % n]
            let p3 = points[(i + 2) % n]

            let cp1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / tension,
                y: p1.y + (p2.y - p0.y) / tension
            )
            let cp2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / tension,
                y: p2.y - (p3.y - p1.y) / tension
            )

            if i == 0 { path.move(to: p1) }
            path.curve(to: p2, controlPoint1: cp1, controlPoint2: cp2)
        }
        path.close()
        return path
    }

    // MARK: - Eyes

    private func drawEyes(center: CGPoint, borderColor: NSColor) {
        let baseEyeRadius: CGFloat = 8 * eyeWidenFactor
        let eyeSpacing: CGFloat = 16
        let eyeY = center.y + 20
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

    // MARK: - Mouth

    private func drawMouth(center: CGPoint, borderColor: NSColor) {
        let mouthY = center.y + 2
        let path = NSBezierPath()
        path.lineWidth = 1.5
        path.lineCapStyle = .round

        switch mood {
        case .content:
            // Gentle smile
            path.move(to: NSPoint(x: center.x - 8, y: mouthY))
            path.curve(to: NSPoint(x: center.x + 8, y: mouthY),
                       controlPoint1: NSPoint(x: center.x - 3, y: mouthY + 4),
                       controlPoint2: NSPoint(x: center.x + 3, y: mouthY + 4))

        case .playful, .delighted:
            // Wide smile
            path.move(to: NSPoint(x: center.x - 11, y: mouthY))
            path.curve(to: NSPoint(x: center.x + 11, y: mouthY),
                       controlPoint1: NSPoint(x: center.x - 4, y: mouthY + 6),
                       controlPoint2: NSPoint(x: center.x + 4, y: mouthY + 6))

        case .angry:
            // Downturned frown
            path.move(to: NSPoint(x: center.x - 8, y: mouthY + 2))
            path.curve(to: NSPoint(x: center.x + 8, y: mouthY + 2),
                       controlPoint1: NSPoint(x: center.x - 3, y: mouthY - 4),
                       controlPoint2: NSPoint(x: center.x + 3, y: mouthY - 4))

        case .annoyed:
            // Flat line
            path.move(to: NSPoint(x: center.x - 7, y: mouthY))
            path.line(to: NSPoint(x: center.x + 7, y: mouthY))

        case .afraid, .alert:
            // Small O
            path.appendOval(in: NSRect(x: center.x - 4, y: mouthY - 3, width: 8, height: 6))

        case .curious:
            // Slightly open
            path.appendOval(in: NSRect(x: center.x - 3, y: mouthY - 2, width: 6, height: 4))

        case .thoughtful:
            // Slight pout
            path.move(to: NSPoint(x: center.x - 6, y: mouthY))
            path.curve(to: NSPoint(x: center.x + 6, y: mouthY),
                       controlPoint1: NSPoint(x: center.x - 2, y: mouthY - 2),
                       controlPoint2: NSPoint(x: center.x + 2, y: mouthY - 2))

        case .offended:
            // Tight pursed line
            path.move(to: NSPoint(x: center.x - 4, y: mouthY))
            path.line(to: NSPoint(x: center.x + 4, y: mouthY))
            path.lineWidth = 2.0
        }

        borderColor.setStroke()
        path.stroke()
    }

    // MARK: - Mouse Tracking

    override func mouseMoved(with event: NSEvent) {
        mouseLocation = event.locationInWindow
        updatePupilTarget()
    }

    private func updatePupilTarget() {
        guard let window = window else { return }
        let windowCenter = CGPoint(x: window.frame.midX, y: window.frame.midY)

        let dx = mouseLocation.x - windowCenter.x
        let dy = mouseLocation.y - windowCenter.y
        let distance = sqrt(dx * dx + dy * dy)

        if distance > 0 {
            let maxOffset: CGFloat = 3
            targetPupilOffsetX = (dx / distance) * maxOffset
            targetPupilOffsetY = (dy / distance) * maxOffset
        }
    }

    // MARK: - Animations

    func startAnimations() {
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let time = Date().timeIntervalSince1970
            self.animationTime = time

            // Breathing with subtle amplitude variation
            let breathAmpVariation = sin(time * 0.13) * 0.02
            let breathe = sin(time) * (0.08 + breathAmpVariation)

            // Bobbing
            let bob = sin(time * 0.5)
            self.bobOffset = bob * 8

            // Squash & stretch from bob velocity
            let bobVelocity = cos(time * 0.5) * 0.5
            let squashStretch: CGFloat = 0.025
            let stretchY = bobVelocity * squashStretch
            self.scaleX = (1.0 + breathe) * (1.0 - stretchY)
            self.scaleY = (1.0 + breathe) * (1.0 + stretchY)

            // Idle drift — layered slow sine waves for organic feel
            self.idleOffsetX = sin(time * 0.3) * 1.5 + sin(time * 0.17) * 0.8
            self.idleOffsetY = cos(time * 0.21) * 1.2 + cos(time * 0.23) * 0.6

            // Smooth pupil lerp
            let lerpFactor: CGFloat = 0.15
            self.pupilOffsetX += (self.targetPupilOffsetX - self.pupilOffsetX) * lerpFactor
            self.pupilOffsetY += (self.targetPupilOffsetY - self.pupilOffsetY) * lerpFactor

            self.setNeedsDisplay(self.bounds)
        }

        scheduleNextBlink()

        self.window?.acceptsMouseMovedEvents = true
        let trackingArea = NSTrackingArea(
            rect: self.bounds,
            options: [.mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        self.addTrackingArea(trackingArea)
    }

    private func scheduleNextBlink() {
        Timer.scheduledTimer(withTimeInterval: Double.random(in: 3...7), repeats: false) { [weak self] _ in
            self?.blink()
            // 15% chance of a quick double-blink
            if Double.random(in: 0...1) < 0.15 {
                Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
                    self?.blink()
                }
            }
            self?.scheduleNextBlink()
        }
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
        }
    }

    func respondingAnimation() {
        isResponding = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isResponding = false
            self?.needsDisplay = true
        }
    }

    // MARK: - Mood

    func setMood(_ newMood: BlobMood, animated: Bool = true) {
        let targetEyeWiden: CGFloat
        switch newMood {
        case .curious:     targetEyeWiden = 1.4
        case .alert:       targetEyeWiden = 1.5
        case .afraid:      targetEyeWiden = 1.65
        case .angry:       targetEyeWiden = 0.7
        case .annoyed:     targetEyeWiden = 0.82
        case .offended:    targetEyeWiden = 0.9
        case .thoughtful:  targetEyeWiden = 0.8
        case .playful, .content, .delighted: targetEyeWiden = 1.0
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

    // MARK: - Colors

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
        }
    }

    // MARK: - Interaction

    override func mouseDown(with event: NSEvent) {
        NotificationCenter.default.post(name: NSNotification.Name("BlobTapped"), object: nil)
    }
}
