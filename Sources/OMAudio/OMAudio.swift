// The Swift Programming Language
// https://docs.swift.org/swift-book

import AudioKit
import AudioKitEX
import Combine
import Foundation
import AVFoundation

/*
    Audio
        record
        play
 
        waveform
    
        buffer (read, write, copy, segment)
 */
public protocol OMAudioManagerDelegate {
    func didStartPlaying()
    func didStopPlaying()
    func didChangeRate(_ rate: Float)
    func didChangeReverse(_ isReversed: Bool)
    func didChangePlayhead(_ playhead: Float)
    
    func didStartRecording()
    func didPauseRecording()
    func didResumeRecording()
    func didCancelRecording()
    func didStopRecording(file: AVAudioFile)
    
    func recordingSpectrum(_ bars: [OMDisplayableBar])
    func recordingDuration(_ elapsed: Double)
    
}

public enum OMAudioError: Error {
    case playerHasNoBuffer
}


public struct OMDisplayableBar {
    public let id: Int
    public let value: CGFloat
    public let hue: CGFloat
}




public class OMAudioManager {
    public init(delegate: OMAudioManagerDelegate?) {
        self.delegate = delegate
    }
    
    public var delegate: OMAudioManagerDelegate?
    
    
    private var _isPlaying = false
    private var _rate: Float = 1
    
    
    
    public var isPlaying: Bool { _isPlaying }
    public var isRecording: Bool { recorder?.isRecording ?? false }
    public var rate: Float { _rate }
    
    private let engine = AudioEngine()
    private var outputMixer = Mixer()
    private var outputLimiter: PeakLimiter?
    private var mic: Fader?
    private var micPassthrough: Fader?
    private var silencer: Fader?
    
    private var recorder: NodeRecorder?
    private var recorderRawTap: RawDataTap?

    private var player = AudioPlayer()
    private var playerRawTap: RawDataTap?
    private var playerFFTTap: RawDataTap?
    private var playerFader: Fader?
    private var playerTimer: Timer? = nil

    private let inputDevices = Settings.session.availableInputs
    private var inputDeviceList = [String]()

    
    private var recordingSpectrumScalar: Float = Float.leastNonzeroMagnitude
    private var recordingTimer: Timer? = nil
    private var recordingCountdownTimer: Timer? = nil
    
    private let queue  =  DispatchQueue(label: "AudioServiceRecording", qos: .userInteractive)

    
    public func start() throws {
        // setup session
        try Settings.session.setCategory(
            .playAndRecord,
            options: [
                .mixWithOthers,
                .allowAirPlay,
                .allowBluetooth,
                .allowBluetoothA2DP,
                .defaultToSpeaker,
            ])
        
        try Settings.session.setActive(true)
        
        if let existingInputs = inputDevices {
            for device in existingInputs {
                inputDeviceList.append(device.portName)
            }
        }
        
        if let input = engine.input {
            
            let micFader =  Fader(input)
            let micPassthrough =  Fader(micFader)
            let silencerFader =  Fader(micPassthrough)
            silencerFader.gain = 0

            self.silencer = silencerFader
            self.mic = micFader
            self.micPassthrough = micPassthrough
            
            let nodeRecorder = try NodeRecorder(node: input)
            recorder = nodeRecorder
            
            outputMixer.addInput(silencerFader)
        }
        
        outputMixer.addInput(player)
        let limiter = PeakLimiter(outputMixer)
        outputLimiter = limiter
        
        engine.output = limiter
        
        try engine.start()
        
    }
    
    
    public func stop() {
        guard engine.avEngine.isRunning else { return }
        engine.stop()
    }
    
    func switchInput(number: Int?) {
            //stop()
            
            if let inputs = Settings.session.availableInputs {
                let newInput = inputs[number ?? 0]
                do {
                    try Settings.session.setPreferredInput(newInput)
                    try Settings.session.setActive(true)
                } catch let error {
                    assertionFailure(error.localizedDescription)
                }
            }
        }


    
    public func load(url: URL) throws {
        
        try player.load(url: url, buffered: true)
        player.pause()
        
        // send loaded signal
    }

    public func play() throws  {
        guard player.buffer != nil else  {
            throw OMAudioError.playerHasNoBuffer
        }
        
        player.play()
        startMonitoringPlayer()
        
        delegate?.didStartPlaying()

    }
    
    public func pause()   {
        guard player.isPlaying else { return }

        player.pause()
        
        stopMonitoringPlayer()
        
        delegate?.didStopPlaying()
    }
    
    public func seek(to percentage: Double) throws {
        
        var seekToTime = (percentage * player.editEndTime)
        let currentTime = player.currentTime
        let seekToAdjusted = seekToTime - currentTime
        
        player.seek(time: seekToAdjusted)

        if !isPlaying {
            player.pause()
//            updatePlayhead(animate: true)
        }
    }
    
    public func step(by seconds: Double) throws {}
    
//    public func speed(to rate: Float) throws {
//        
//
//    }
    
    public func reverse(_ isReversed: Bool = true) throws {
        pause()
        player.isReversed = true
    }
    

    
    private   func playerCompletionHandler() {
        // ensure we hit the end
        DispatchQueue.main.async {
//            self.playerElapsed.send(self.player.duration)
//            self.playerPercentage.value = 1
//            self.status.value =  .readyToPlay
        }
        // looping?
        stopMonitoringPlayer()
    }
    
    private func startMonitoringPlayer() {
        
        
        playerTimer = Timer.scheduledTimer(timeInterval: 0.1,
                                              target: self,
                                              selector: #selector(playheadTimerCallback),
                                              userInfo: nil,
                                              repeats: true)
        
        // player live tap
        
        
    }
    
    private func stopMonitoringPlayer() {
        playerTimer?.invalidate()
        playerTimer = nil
    }
    
    @objc func playheadTimerCallback() {
        let percentage = player.currentTime / player.duration
        let elapsed = player.currentTime
//        DispatchQueue.main.async {
//            self.playerElapsed.send(elapsed)
//            self.playerPercentage.set(percentage)
    }
    
    
    /* RECORDING
        
     
     */
    
    
    public func startRecording() throws {
        if self.recorder?.isRecording ?? false {
            try cancelRecording()
        }
        try self.recorder?.reset()
        try self.recorder?.record()
        startMonitoringRecording()
        delegate?.didStartRecording()
        
    }
    
    @objc func timerCallback() {
        if let duration = recorder?.recordedDuration {
            delegate?.recordingDuration(duration)
        }
    }

    public func pauseRecording()  {
        guard recorder?.isRecording ?? true else { return }
        
        recorder?.pause()
        
        stopMonitoringRecording()
        
        delegate?.didPauseRecording()

    }
    
    public func resumeRecording()  {
        recorder?.resume()

        startMonitoringRecording()
        
        delegate?.didResumeRecording()
    }
    
    var recordedURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("recording").appendingPathExtension("caf")
    }
    
    public func stopRecording() throws {
        guard recorder?.isRecording ?? true else { return  }
        self.recorder?.stop()
        stopMonitoringRecording()

        if let file = recorder?.audioFile {
            delegate?.didStopRecording(file: file)
        }
    }
    public func cancelRecording() throws {
        guard recorder?.isRecording ?? true else { return }

        recorder?.stop()

        stopMonitoringRecording()
        
        delegate?.didCancelRecording()
    }

    private func startMonitoringRecording() {
        recordingSpectrumScalar = Float.leastNonzeroMagnitude
        if let input = micPassthrough {
            self.recorderRawTap = RawDataTap(input,
                                             bufferSize: 2048,
                                             callbackQueue: self.queue) { [weak self] data in
                guard let strongSelf = self else { return }
                let amps = data.downsample(numBins: 32)
                let noiseFloor = Float(50)
//                print(amps)
                var bars = [OMDisplayableBar](repeating: .init(id: 0, value: 0, hue: 0), count: amps.count)
                for i in 0..<amps.count {
                    let normalized = CGFloat(abs(amps[i])).mapped(from: 0...50, to: 0...1)
                    var hue =  normalized.mapped(from: 0...1, to: 0.666...1)
                    let clamped = min(max( normalized, 0.01), 1.0)
                    bars[i] = OMDisplayableBar(id: i, value: clamped, hue: hue)
                }
                DispatchQueue.main.async {
                    strongSelf.delegate?.recordingSpectrum(bars)
                }
            }
            
            self.recorderRawTap?.start()
        }
        
        recordingTimer = Timer.scheduledTimer(timeInterval: 0.1,
                                              target: self,
                                              selector: #selector(timerCallback),
                                              userInfo: nil,
                                              repeats: true)
    }
      
    private func stopMonitoringRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recorderRawTap?.stop()
        recorderRawTap = nil
    }
    
  
    deinit {
        stopMonitoringRecording()
    }
    
}

