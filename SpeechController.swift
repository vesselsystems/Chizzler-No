import AVFoundation
import Foundation
import Speech

final class SpeechController {
    enum SpeechError: LocalizedError {
        case recognizerUnavailable
        case speechNotAuthorized
        case microphoneNotAuthorized

        var errorDescription: String? {
            switch self {
            case .recognizerUnavailable:
                return "Speech recognizer is unavailable for the current locale."
            case .speechNotAuthorized:
                return "Enable Speech Recognition permission for the app."
            case .microphoneNotAuthorized:
                return "Enable Microphone permission for the app."
            }
        }
    }

    private let logger = DebugLogger.shared
    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var transcript = ""
    private var stopContinuation: CheckedContinuation<String, Never>?
    private var stopTimeoutTask: DispatchWorkItem?
    private var isRecording = false

    @MainActor
    func requestPermissions() async throws {
        guard recognizer != nil else {
            throw SpeechError.recognizerUnavailable
        }

        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard speechStatus == .authorized else {
            throw SpeechError.speechNotAuthorized
        }

        let microphoneGranted = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }

        guard microphoneGranted else {
            throw SpeechError.microphoneNotAuthorized
        }
    }

    func startRecording() throws {
        guard !isRecording else {
            logger.log("speech", "ignored startRecording because controller is already recording")
            return
        }

        stopEngineIfNeeded()
        transcript = ""
        stopTimeoutTask?.cancel()

        guard let recognizer, recognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
        logger.log("speech", "recording started")

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let text = result?.bestTranscription.formattedString {
                self.transcript = text
            }

            if let result, result.isFinal {
                self.logger.log("speech", "received final transcript callback")
                self.finishStopIfNeeded(with: self.transcript)
            } else if let error {
                self.logger.log("speech", "recognition completed with error: \(error.localizedDescription)")
                self.finishStopIfNeeded(with: self.transcript)
            }
        }
    }

    func stopRecording() async -> String {
        guard isRecording else {
            logger.log("speech", "stopRecording called with no active recording")
            return transcript
        }

        logger.log("speech", "recording stop requested")
        isRecording = false
        request?.endAudio()
        task?.finish()
        stopEngine()

        return await withCheckedContinuation { continuation in
            stopContinuation = continuation

            let timeoutTask = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.logger.log("speech", "final transcript timeout reached")
                self.finishStopIfNeeded(with: self.transcript)
            }

            stopTimeoutTask = timeoutTask
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: timeoutTask)
        }
    }

    func cancelRecording() {
        guard isRecording || stopContinuation != nil else {
            logger.log("speech", "ignored cancelRecording because controller is idle")
            return
        }

        logger.log("speech", "recording canceled")
        isRecording = false
        stopTimeoutTask?.cancel()
        if let continuation = stopContinuation {
            stopContinuation = nil
            continuation.resume(returning: "")
        }
        transcript = ""
        task?.cancel()
        request?.endAudio()
        stopEngineIfNeeded()
    }

    private func stopEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
    }

    private func stopEngineIfNeeded() {
        stopTimeoutTask?.cancel()
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        task?.cancel()
        task = nil
        request = nil
    }

    private func finishStopIfNeeded(with finalTranscript: String) {
        guard let continuation = stopContinuation else { return }

        stopTimeoutTask?.cancel()
        stopContinuation = nil
        task?.cancel()
        task = nil
        request = nil
        transcript = ""
        logger.log("speech", "recording finalized with \(finalTranscript.isEmpty ? "empty" : "non-empty") transcript")
        continuation.resume(returning: finalTranscript)
    }
}
