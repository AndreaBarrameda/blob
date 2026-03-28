import Foundation
import AVFoundation

protocol BlobVoiceAgentDelegate: AnyObject {
    func voiceAgentDidConnect()
    func voiceAgentDidDisconnect()
    func voiceAgentUserSaid(_ text: String)
    func voiceAgentBlobSaid(_ text: String)
    func voiceAgentStateChanged(_ state: String)
}

/// Direct WebSocket connection to ElevenLabs Conversational AI agent.
/// No SDK — just raw WebSocket + PCM audio streaming.
class BlobVoiceAgent: NSObject, URLSessionWebSocketDelegate {
    static let agentId = "agent_2201kmtn45b4fagvgqkaac3yxd06"
    private let wsURL = "wss://api.elevenlabs.io/v1/convai/conversation?agent_id=\(agentId)"

    weak var delegate: BlobVoiceAgentDelegate?
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var inputEngine: AVAudioEngine?      // mic capture
    private var outputEngine: AVAudioEngine?      // audio playback
    private var playerNode: AVAudioPlayerNode?
    private var isConnected = false

    // Audio config — ElevenLabs uses PCM 16kHz mono signed 16-bit LE
    private let outputSampleRate: Double = 16000
    private var inputSampleRate: Double = 48000
    private lazy var outputFormat: AVAudioFormat = {
        AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: outputSampleRate, channels: 1, interleaved: true)!
    }()

    // Audio buffering — accumulate small chunks before scheduling
    private var pendingAudioData = Data()
    private let audioScheduleQueue = DispatchQueue(label: "blob.audio.schedule")
    private let minBufferBytes = 3200 // 100ms at 16kHz 16-bit (1600 samples * 2 bytes)
    private var flushTimer: DispatchWorkItem?

    // Mic gating — mute mic while agent speaks so it doesn't interrupt itself
    private var agentIsSpeaking = false
    private var resumeMicTimer: DispatchWorkItem?

    var isActive: Bool { isConnected }

    override init() {
        super.init()
    }

    // MARK: - Connect / Disconnect

    func start() {
        guard !isConnected else { return }
        print("🗣️ Connecting to ElevenLabs agent via WebSocket...")

        let config = URLSessionConfiguration.default
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        guard let url = URL(string: wsURL) else {
            print("🗣️ Invalid WebSocket URL")
            return
        }

        webSocket = urlSession?.webSocketTask(with: url)
        webSocket?.resume()
        receiveMessage()
    }

    func stop() {
        print("🗣️ Disconnecting...")
        stopMicCapture()
        stopOutputEngine()
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        urlSession = nil
        isConnected = false
        delegate?.voiceAgentDidDisconnect()
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol proto: String?) {
        print("🗣️ WebSocket connected!")
        isConnected = true

        // Send initiation message
        let initData: [String: Any] = ["type": "conversation_initiation_client_data"]
        if let json = try? JSONSerialization.data(withJSONObject: initData),
           let str = String(data: json, encoding: .utf8) {
            webSocket?.send(.string(str)) { error in
                if let error = error { print("🗣️ Init send error: \(error)") }
            }
        }

        setupOutputEngine()
        startMicCapture()
        DispatchQueue.main.async { self.delegate?.voiceAgentDidConnect() }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let reasonStr = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "none"
        print("🗣️ WebSocket closed: code=\(closeCode.rawValue) reason=\(reasonStr)")
        isConnected = false
        stopMicCapture()
        stopOutputEngine()
        DispatchQueue.main.async { self.delegate?.voiceAgentDidDisconnect() }
    }

    // MARK: - Receive Messages

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text): self.handleServerMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleServerMessage(text)
                    }
                @unknown default: break
                }
                self.receiveMessage()
            case .failure(let error):
                print("🗣️ WebSocket receive error: \(error.localizedDescription)")
                self.isConnected = false
            }
        }
    }

    private func handleServerMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "conversation_initiation_metadata":
            if let meta = json["conversation_initiation_metadata_event"] as? [String: Any],
               let convId = meta["conversation_id"] as? String {
                print("🗣️ Conversation started: \(convId)")
            }

        case "audio":
            if let event = json["audio_event"] as? [String: Any],
               let base64Audio = event["audio_base_64"] as? String,
               let audioData = Data(base64Encoded: base64Audio) {
                // Agent is producing audio — mute mic to prevent self-interruption
                agentIsSpeaking = true
                resumeMicTimer?.cancel()
                scheduleAudioForPlayback(audioData)

                // Schedule mic resume after audio stops arriving (500ms grace)
                let work = DispatchWorkItem { [weak self] in
                    self?.agentIsSpeaking = false
                    // Back to listening — set curious mood
                    self?.delegate?.voiceAgentStateChanged("listening")
                }
                resumeMicTimer = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
            }

        case "user_transcript":
            if let event = json["user_transcription_event"] as? [String: Any],
               let transcript = event["user_transcript"] as? String,
               !transcript.isEmpty {
                print("🗣️ User said: \"\(transcript)\"")
                DispatchQueue.main.async { self.delegate?.voiceAgentUserSaid(transcript) }
            }

        case "agent_response":
            if let event = json["agent_response_event"] as? [String: Any],
               let response = event["agent_response"] as? String,
               !response.isEmpty {
                print("🗣️ Blob said: \"\(response)\"")
                DispatchQueue.main.async { self.delegate?.voiceAgentBlobSaid(response) }
            }

        case "ping":
            if let eventId = json["ping_event"] as? [String: Any],
               let id = eventId["event_id"] as? Int {
                let pong: [String: Any] = ["type": "pong", "event_id": id]
                if let pongData = try? JSONSerialization.data(withJSONObject: pong),
                   let pongStr = String(data: pongData, encoding: .utf8) {
                    webSocket?.send(.string(pongStr)) { _ in }
                }
            }

        case "interruption":
            // Ignore — mic is muted while speaking, so let audio play to completion
            break

        default:
            break
        }
    }

    // MARK: - Gapless Audio Playback via AVAudioEngine

    private func setupOutputEngine() {
        outputEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        guard let engine = outputEngine, let player = playerNode else { return }

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: outputFormat)

        do {
            try engine.start()
            player.play()
            print("🗣️ Audio output engine started")
        } catch {
            print("🗣️ Output engine error: \(error)")
        }
    }

    private func stopOutputEngine() {
        playerNode?.stop()
        outputEngine?.stop()
        playerNode = nil
        outputEngine = nil
    }

    private func scheduleAudioForPlayback(_ pcmData: Data) {
        audioScheduleQueue.async { [weak self] in
            guard let self = self else { return }
            self.pendingAudioData.append(pcmData)

            // Wait until we have enough data for smooth playback
            if self.pendingAudioData.count >= self.minBufferBytes {
                self.flushPendingAudio()
            }

            // Also schedule a flush after 80ms of no new data (catches the tail end)
            self.flushTimer?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.flushPendingAudio()
            }
            self.flushTimer = work
            self.audioScheduleQueue.asyncAfter(deadline: .now() + 0.08, execute: work)
        }
    }

    private func flushPendingAudio() {
        // Must be called on audioScheduleQueue
        guard !pendingAudioData.isEmpty else { return }
        guard let player = playerNode, let engine = outputEngine, engine.isRunning else { return }

        let data = pendingAudioData
        pendingAudioData = Data()

        let sampleCount = data.count / 2
        guard sampleCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: AVAudioFrameCount(sampleCount)) else { return }

        buffer.frameLength = AVAudioFrameCount(sampleCount)
        data.withUnsafeBytes { rawPtr in
            if let src = rawPtr.baseAddress {
                memcpy(buffer.int16ChannelData![0], src, data.count)
            }
        }

        player.scheduleBuffer(buffer, completionHandler: nil)
    }

    // MARK: - Microphone Capture & Streaming

    private func startMicCapture() {
        inputEngine = AVAudioEngine()
        guard let engine = inputEngine else { return }

        if let micID = findPhysicalMic() {
            do {
                try engine.inputNode.auAudioUnit.setDeviceID(micID)
            } catch {
                print("🗣️ Could not set mic device: \(error)")
            }
        }

        let hwFormat = engine.inputNode.outputFormat(forBus: 0)
        inputSampleRate = hwFormat.sampleRate

        guard let monoFormat = AVAudioFormat(standardFormatWithSampleRate: hwFormat.sampleRate, channels: 1) else { return }

        engine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: monoFormat) { [weak self] buffer, _ in
            self?.sendAudioToWebSocket(buffer)
        }

        do {
            try engine.start()
            print("🗣️ Mic streaming at \(hwFormat.sampleRate)Hz → 16kHz")
        } catch {
            print("🗣️ Mic start error: \(error)")
        }
    }

    private func stopMicCapture() {
        inputEngine?.inputNode.removeTap(onBus: 0)
        inputEngine?.stop()
        inputEngine = nil
    }

    private func sendAudioToWebSocket(_ buffer: AVAudioPCMBuffer) {
        guard isConnected, !agentIsSpeaking, let channelData = buffer.floatChannelData else { return }

        let frameLength = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))

        // Downsample to 16kHz
        let ratio = inputSampleRate / outputSampleRate
        let outputLength = Int(Double(frameLength) / ratio)
        var resampled = [Int16](repeating: 0, count: outputLength)

        for i in 0..<outputLength {
            let srcIdx = min(Int(Double(i) * ratio), frameLength - 1)
            resampled[i] = Int16(max(-1.0, min(1.0, samples[srcIdx])) * 32767)
        }

        let pcmData = resampled.withUnsafeBufferPointer { Data(buffer: $0) }
        let base64 = pcmData.base64EncodedString()
        let msg = "{\"user_audio_chunk\":\"\(base64)\"}"
        webSocket?.send(.string(msg)) { _ in }
    }

    // MARK: - Find Physical Mic

    private func findPhysicalMic() -> AudioDeviceID? {
        var propSize: UInt32 = 0
        var devicesAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &devicesAddr, 0, nil, &propSize)
        let count = Int(propSize) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &devicesAddr, 0, nil, &propSize, &ids)

        for devID in ids {
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
            let inputCh = (0..<Int(bufferList.pointee.mNumberBuffers)).reduce(0) { t, i in
                t + Int(UnsafeMutableAudioBufferListPointer(bufferList)[i].mNumberChannels)
            }
            guard inputCh > 0 else { continue }

            var name = "" as CFString
            var nameSize = UInt32(MemoryLayout<CFString>.size)
            var nameAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectGetPropertyData(devID, &nameAddr, 0, nil, &nameSize, &name)
            let devName = (name as String).lowercased()
            if devName.contains("macbook") || devName.contains("built-in") || devName.contains("microphone") {
                print("🗣️ Using mic: \(name) (ID: \(devID))")
                return devID
            }
        }

        var defaultID = AudioDeviceID(0)
        var defaultSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var defaultAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultAddr, 0, nil, &defaultSize, &defaultID) == noErr {
            return defaultID
        }
        return nil
    }
}
