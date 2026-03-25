import SwiftUI

struct BlobView: View {
    @State private var scale: CGFloat = 1.0
    @State private var bobOffset: CGFloat = 0
    @State private var leftEyeScale: CGFloat = 1.0
    @State private var rightEyeScale: CGFloat = 1.0
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            // Blob body with breathing animation
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.8, green: 0.7, blue: 0.95),
                            Color(red: 0.6, green: 0.5, blue: 0.85)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 50
                    )
                )
                .scaleEffect(scale)
                .shadow(color: Color.purple.opacity(0.4), radius: 8)

            // Eyes with blinking
            HStack(spacing: 14) {
                EyeView(scale: leftEyeScale)
                EyeView(scale: rightEyeScale)
            }
            .offset(y: -10)
        }
        .frame(width: 180, height: 180)
        .offset(y: bobOffset)
        .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
        .onTapGesture {
            NotificationCenter.default.post(name: NSNotification.Name("BlobTapped"), object: nil)
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // Breathing animation (pulsing in and out)
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            scale = 1.08
        }

        // Bobbing animation (gentle up and down)
        Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                bobOffset = 8
            }
        }

        // Blinking animation
        Timer.scheduledTimer(withTimeInterval: Double.random(in: 3...6), repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                leftEyeScale = 0.2
                rightEyeScale = 0.2
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    leftEyeScale = 1.0
                    rightEyeScale = 1.0
                }
            }
        }

        // Gentle rotation/wobble
        Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                rotation = 3
            }
        }
    }
}

struct EyeView: View {
    let scale: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 16, height: 16)

            Circle()
                .fill(Color.black)
                .frame(width: 6, height: 6)
        }
        .scaleEffect(y: scale)
    }
}

#Preview {
    BlobView()
}
