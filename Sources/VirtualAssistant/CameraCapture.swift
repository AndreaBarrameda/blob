import Foundation
import AVFoundation
import Vision
import AppKit
import CoreImage

class CameraCapture: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var lastFrame: CVPixelBuffer?
    private let queue = DispatchQueue(label: "com.blob.camera")

    func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    func startCapture() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        print("📷 Camera auth status: \(status.rawValue)")

        guard status == .authorized else {
            print("❌ Camera not authorized (status: \(status))")
            return
        }

        queue.async {
            print("📷 Starting capture session...")
            self.setupCaptureSession()
        }
    }

    func stopCapture() {
        captureSession?.stopRunning()
        print("📷 Camera stopped")
    }

    func captureFrame(completion: @escaping (NSImage?) -> Void) {
        queue.async {
            print("📷 Attempting to capture frame... (lastFrame: \(self.lastFrame != nil))")

            if let pixelBuffer = self.lastFrame {
                print("📷 Converting pixel buffer to NSImage...")
                let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                let context = CIContext()
                if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                    let nsImage = NSImage(cgImage: cgImage, size: NSZeroSize)
                    print("📷 Frame captured successfully")
                    DispatchQueue.main.async {
                        completion(nsImage)
                    }
                    return
                }
            }
            print("📷 No frame available")
            DispatchQueue.main.async {
                completion(nil)
            }
        }
    }

    func captureFrameAsBase64(completion: @escaping (String?) -> Void) {
        captureFrame { image in
            guard let image = image else {
                print("📷 No image captured")
                completion(nil)
                return
            }

            print("📷 Image captured, converting to base64...")

            if let tiffData = image.tiffRepresentation,
               let bitmapImage = NSBitmapImageRep(data: tiffData),
               let jpegData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.4]) {
                let base64 = jpegData.base64EncodedString()
                print("📷 Base64 encoded: \(base64.count) characters")
                completion(base64)
            } else {
                print("📷 Failed to encode image")
                completion(nil)
            }
        }
    }

    private func setupCaptureSession() {
        print("📷 Setting up capture session...")
        let session = AVCaptureSession()
        session.sessionPreset = .medium

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            print("❌ No front camera found")
            return
        }

        print("📷 Found front camera: \(camera.localizedName)")

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
                print("📷 Added camera input")
            } else {
                print("❌ Cannot add camera input")
                return
            }

            let output = AVCaptureVideoDataOutput()
            output.setSampleBufferDelegate(self, queue: queue)
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]

            if session.canAddOutput(output) {
                session.addOutput(output)
                self.videoOutput = output
                print("📷 Added video output")
            } else {
                print("❌ Cannot add video output")
                return
            }

            session.startRunning()
            self.captureSession = session
            print("📷 Camera session started ✓ (running: \(session.isRunning))")
        } catch {
            print("❌ Camera error: \(error)")
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastFrame = pixelBuffer
        print("📷 Frame received from camera")
    }
}
