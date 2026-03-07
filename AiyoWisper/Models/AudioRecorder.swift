@preconcurrency import AVFoundation
import Foundation

@Observable
final class AudioRecorder {
    enum State {
        case idle
        case recording
        case processing
    }

    private(set) var state: State = .idle

    private var audioEngine: AVAudioEngine?
    private var samples: [Float] = []
    private let lock = NSLock()

    func startRecording() throws {
        samples = []
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Constants.Audio.sampleRate,
            channels: 1,
            interleaved: false
        )!

        if inputFormat.sampleRate != Constants.Audio.sampleRate || inputFormat.channelCount != 1 {
            guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
                throw AudioRecorderError.converterCreationFailed
            }

            inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
                guard let self else { return }
                let frameCapacity = AVAudioFrameCount(
                    Double(buffer.frameLength) * Constants.Audio.sampleRate / inputFormat.sampleRate
                )
                guard let convertedBuffer = AVAudioPCMBuffer(
                    pcmFormat: targetFormat, frameCapacity: frameCapacity
                ) else { return }

                var error: NSError?
                let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }

                if status == .haveData, let channelData = convertedBuffer.floatChannelData {
                    let count = Int(convertedBuffer.frameLength)
                    let newSamples = Array(UnsafeBufferPointer(start: channelData[0], count: count))
                    self.lock.lock()
                    self.samples.append(contentsOf: newSamples)
                    self.lock.unlock()
                }
            }
        } else {
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: targetFormat) { [weak self] buffer, _ in
                guard let self, let channelData = buffer.floatChannelData else { return }
                let count = Int(buffer.frameLength)
                let newSamples = Array(UnsafeBufferPointer(start: channelData[0], count: count))
                self.lock.lock()
                self.samples.append(contentsOf: newSamples)
                self.lock.unlock()
            }
        }

        engine.prepare()
        try engine.start()
        audioEngine = engine
        state = .recording
    }

    func stopRecording() -> [Float] {
        state = .processing
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil

        lock.lock()
        let result = samples
        samples = []
        lock.unlock()

        state = .idle
        return result
    }
}

enum AudioRecorderError: LocalizedError {
    case converterCreationFailed

    var errorDescription: String? {
        switch self {
        case .converterCreationFailed:
            return "Failed to create audio format converter"
        }
    }
}
