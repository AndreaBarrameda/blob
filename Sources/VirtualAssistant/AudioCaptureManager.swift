import Foundation
import AVFoundation

protocol AudioCaptureDelegate: AnyObject {
    func audioCaptureDidDetectSpeech(_ audioData: Data)
}

class AudioCaptureManager: NSObject {
    weak var delegate: AudioCaptureDelegate?
    private var audioEngine: AVAudioEngine?
    private var audioBuffer: [Float] = []
    private var isRecording = false
    private var isMuted = false // mute during TTS playback to prevent feedback

    // Voice activity detection
    private var isSpeaking = false
    private var silenceFrames = 0
    private let speechThreshold: Float = 0.01      // RMS above this = speech (well above ambient ~0.005)
    private let silenceThreshold: Float = 0.008    // RMS below this = silence (above ambient, below speech)
    private var rmsLogCounter = 0
    private let silenceFramesToEnd = 8              // ~0.4s of silence ends capture (faster cutoff)
    private var actualSampleRate: Double = 48000
    private let minSpeechSamples = 12000            // minimum 0.25s of speech
    private let maxSpeechSamples = 144000           // maximum 3s per chunk (low latency)

    override init() {
        super.init()
    }

    func startCapturing() {
        guard !isRecording else { return }
        print("🎙️ Requesting microphone permission...")

        // Check/request microphone permission first
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            print("🎙️ Microphone permission: authorized")
            setupAudioEngine()
            isRecording = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                if granted {
                    print("🎙️ Microphone permission: granted")
                    DispatchQueue.main.async {
                        self?.setupAudioEngine()
                        self?.isRecording = true
                    }
                } else {
                    print("🎙️ Microphone permission: denied by user")
                }
            }
        case .denied:
            print("🎙️ Microphone permission: denied — open System Settings → Privacy & Security → Microphone")
        case .restricted:
            print("🎙️ Microphone permission: restricted")
        @unknown default:
            print("🎙️ Microphone permission: unknown status")
        }
    }

    func stopCapturing() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isRecording = false
        isSpeaking = false
        audioBuffer.removeAll()
        silenceFrames = 0
        print("🎙️ Audio capture stopped")
    }

    /// Mute mic during TTS playback to prevent feedback loop
    func mute() { isMuted = true }
    func unmute() {
        isMuted = false
        audioBuffer.removeAll()
        isSpeaking = false
        silenceFrames = 0
    }

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }

        // Find and set the actual default input device
        if let micID = findDefaultInputDevice() {
            do {
                try engine.inputNode.auAudioUnit.setDeviceID(micID)
                print("🎙️ Set input device to ID: \(micID)")
            } catch {
                print("🎙️ Could not set input device: \(error)")
            }
        }

        let inputNode = engine.inputNode
        let hwFormat = inputNode.outputFormat(forBus: 0)
        print("🎙️ Hardware format: \(hwFormat.channelCount)ch, \(hwFormat.sampleRate)Hz")

        // Use mono format for the tap — ensures mic data lands on channel 0
        guard let monoFormat = AVAudioFormat(standardFormatWithSampleRate: hwFormat.sampleRate, channels: 1) else {
            print("🎙️ Failed to create mono format")
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: monoFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }

        do {
            try engine.start()
            actualSampleRate = hwFormat.sampleRate
            print("🎙️ Audio engine started (mono tap at \(hwFormat.sampleRate)Hz)")
        } catch {
            print("🎙️ Audio engine error: \(error)")
        }
    }

    private func findDefaultInputDevice() -> AudioDeviceID? {
        // List all audio devices and find input-capable ones
        var propSize: UInt32 = 0
        var devicesAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &devicesAddr, 0, nil, &propSize)
        let deviceCount = Int(propSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &devicesAddr, 0, nil, &propSize, &deviceIDs)

        var physicalMic: AudioDeviceID? = nil
        var systemDefault: AudioDeviceID? = nil

        for devID in deviceIDs {
            // Check if device has input channels
            var inputAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            var bufSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(devID, &inputAddr, 0, nil, &bufSize) == noErr, bufSize > 0 else { continue }

            let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
            defer { bufferList.deallocate() }
            guard AudioObjectGetPropertyData(devID, &inputAddr, 0, nil, &bufSize, bufferList) == noErr else { continue }
            let inputChannels = (0..<Int(bufferList.pointee.mNumberBuffers)).reduce(0) { total, i in
                total + Int(UnsafeMutableAudioBufferListPointer(bufferList)[i].mNumberChannels)
            }
            guard inputChannels > 0 else { continue }

            // Get device name
            var name = "" as CFString
            var nameSize = UInt32(MemoryLayout<CFString>.size)
            var nameAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectGetPropertyData(devID, &nameAddr, 0, nil, &nameSize, &name)
            let deviceName = name as String
            print("🎙️ Found input device: \(deviceName) (ID: \(devID), \(inputChannels)ch)")

            // Prefer built-in or physical mic over virtual ones
            let lower = deviceName.lowercased()
            if lower.contains("macbook") || lower.contains("built-in") || lower.contains("internal") || lower.contains("microphone") {
                physicalMic = devID
                print("🎙️ → Selected as physical mic")
            }
        }

        // Get system default as fallback
        var defaultID = AudioDeviceID(0)
        var defaultSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var defaultAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultAddr, 0, nil, &defaultSize, &defaultID) == noErr {
            systemDefault = defaultID
        }

        // Prefer physical mic, fall back to system default
        if let mic = physicalMic {
            print("🎙️ Using physical mic (ID: \(mic))")
            return mic
        }
        if let def = systemDefault {
            print("🎙️ Using system default input (ID: \(def))")
            return def
        }
        print("🎙️ No input device found")
        return nil
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard !isMuted else { return }
        guard let channelData = buffer.floatChannelData else { return }

        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        // Try to find a channel with actual audio data (some devices put mic on channel 1)
        var samples: [Float] = []
        let channelCount = Int(buffer.format.channelCount)
        for ch in 0..<channelCount {
            let channelSamples = Array(UnsafeBufferPointer(start: channelData[ch], count: frameLength))
            let chRMS = sqrt(channelSamples.map { $0 * $0 }.reduce(0, +) / Float(frameLength))
            if chRMS > 0 {
                samples = channelSamples
                break
            }
        }
        if samples.isEmpty {
            samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
        }

        // Calculate RMS energy
        let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(frameLength))

        // Log RMS every ~2 seconds so we can see mic levels
        rmsLogCounter += 1
        if rmsLogCounter % 24 == 0 {
            print("🎙️ Mic RMS: \(String(format: "%.6f", rms)) \(rms > speechThreshold ? "🔴 SPEECH" : "⚪️ quiet")")
        }

        if !isSpeaking {
            // Waiting for speech to start
            if rms > speechThreshold {
                isSpeaking = true
                silenceFrames = 0
                audioBuffer.removeAll()
                audioBuffer.append(contentsOf: samples)
                print("🎙️ Speech detected (RMS: \(String(format: "%.4f", rms)))")
            }
        } else {
            // Currently capturing speech
            audioBuffer.append(contentsOf: samples)

            if rms < silenceThreshold {
                silenceFrames += 1
                if silenceFrames >= silenceFramesToEnd {
                    // Speech ended — send chunk if long enough
                    finalizeSpeechChunk()
                }
            } else {
                silenceFrames = 0
            }

            // Safety cap — don't buffer more than 10s
            if audioBuffer.count >= maxSpeechSamples {
                finalizeSpeechChunk()
            }
        }
    }

    private func finalizeSpeechChunk() {
        isSpeaking = false
        silenceFrames = 0

        guard audioBuffer.count >= minSpeechSamples else {
            print("🎙️ Speech too short (\(audioBuffer.count) samples), ignoring")
            audioBuffer.removeAll()
            return
        }

        let wavData = convertPCMToWAV(audioBuffer)
        audioBuffer.removeAll()

        print("🎙️ Speech chunk ready (\(wavData.count / 1024)KB, \(String(format: "%.1f", Double(wavData.count) / 88200.0))s)")
        delegate?.audioCaptureDidDetectSpeech(wavData)
    }

    private func convertPCMToWAV(_ samples: [Float]) -> Data {
        var wavData = Data()

        let sampleRate: UInt32 = UInt32(actualSampleRate)
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16

        wavData.append("RIFF".data(using: .ascii)!)
        let audioDataSize = UInt32(samples.count * 2)
        let fileSize = 36 + audioDataSize
        wavData.append(withUnsafeBytes(of: fileSize.littleEndian) { Data($0) })
        wavData.append("WAVE".data(using: .ascii)!)
        wavData.append("fmt ".data(using: .ascii)!)
        wavData.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: channels.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        wavData.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        let blockAlign = UInt16(channels * bitsPerSample / 8)
        wavData.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })
        wavData.append("data".data(using: .ascii)!)
        wavData.append(withUnsafeBytes(of: audioDataSize.littleEndian) { Data($0) })

        for sample in samples {
            let int16Sample = Int16(max(-1.0, min(1.0, sample)) * 32767)
            wavData.append(withUnsafeBytes(of: int16Sample.littleEndian) { Data($0) })
        }

        return wavData
    }
}
