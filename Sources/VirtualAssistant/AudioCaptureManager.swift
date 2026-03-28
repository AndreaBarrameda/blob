import Foundation
import AVFoundation

class AudioCaptureManager: NSObject, AVAudioRecorderDelegate {
    private var audioRecorder: AVAudioRecorder?
    private var audioEngine: AVAudioEngine?
    private var audioBuffer: [Float] = []
    private var isRecording = false

    override init() {
        super.init()
        setupAudio()
    }

    private func setupAudio() {
        #if os(macOS)
        // Audio session setup not needed on macOS
        #else
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: [])
        } catch {
            print("🎙️ Audio session setup failed: \(error)")
        }
        #endif
    }

    func startCapturing() {
        setupAudioEngine()
        isRecording = true
        print("🎙️ Audio capture started")
    }

    func stopCapturing() {
        audioEngine?.stop()
        isRecording = false
        print("🎙️ Audio capture stopped")
    }

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }

        do {
            try engine.start()
            print("🎙️ Audio engine started")
        } catch {
            print("🎙️ Audio engine error: \(error)")
        }
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let frameLength = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))

        audioBuffer.append(contentsOf: samples)

        // When we have enough samples (approximately 5 seconds at typical sample rate)
        // send for transcription
        if audioBuffer.count > 220500 { // ~5 seconds at 44.1kHz
            let audioData = convertPCMToWAV(audioBuffer)
            audioBuffer.removeAll()

            print("🎙️ Audio chunk ready (\(audioData.count) bytes)")
            // TODO: Wire audio to OpenAIClient.transcribeAudio() to complete the pipeline.
            // Needs a delegate/callback to send audioData to AppDelegate for transcription.
        }
    }

    private func convertPCMToWAV(_ samples: [Float]) -> Data {
        var wavData = Data()

        let sampleRate: UInt32 = 44100
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16

        // WAV header
        wavData.append("RIFF".data(using: .ascii)!)

        let audioDataSize = UInt32(samples.count * 2)
        let fileSize = 36 + audioDataSize
        wavData.append(withUnsafeBytes(of: fileSize.littleEndian) { Data($0) })

        wavData.append("WAVE".data(using: .ascii)!)
        wavData.append("fmt ".data(using: .ascii)!)
        wavData.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) }) // PCM
        wavData.append(withUnsafeBytes(of: channels.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })

        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        wavData.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })

        let blockAlign = UInt16(channels * bitsPerSample / 8)
        wavData.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })

        // Audio data
        wavData.append("data".data(using: .ascii)!)
        wavData.append(withUnsafeBytes(of: audioDataSize.littleEndian) { Data($0) })

        for sample in samples {
            let int16Sample = Int16(sample * 32767)
            wavData.append(withUnsafeBytes(of: int16Sample.littleEndian) { Data($0) })
        }

        return wavData
    }

    func getAudioData(completion: @escaping (Data?) -> Void) {
        // This will be called periodically to get buffered audio
        let audioData = convertPCMToWAV(audioBuffer)
        audioBuffer.removeAll()

        if audioData.count > 100 {
            completion(audioData)
        } else {
            completion(nil)
        }
    }
}
