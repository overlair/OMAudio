//
//  File.swift
//  
//
//  Created by John Knowles on 7/15/24.
//

import AVFoundation
import Accelerate

// Request to get data out of an audio file
public class WaveformRequest {
    /// Audio file get data from
    public private(set) var audioFile: AVAudioFile?
    
    var peakValue: Float? = nil
    var tileSize: UInt32? = nil

    struct CacheKey: Hashable {
        let offset: Int
        let zoom: CGFloat
    }
    
    private var waveformCache: [CacheKey: [Float]] = [:]

    
    private let abortWaveformDataQueue = DispatchQueue(label: "WaveformDataRequest.abortWaveformDataQueue",
                                                       attributes: .concurrent)

    private var _abortGetWaveformData: [Int: Bool] = [:]
    /// Should we abort the waveform data
    public var abortGetWaveformData: [Int: Bool] {
        get { _abortGetWaveformData }
        set {
            abortWaveformDataQueue.async(flags: .barrier) {
                self._abortGetWaveformData = newValue
            }
        }
    }
    

    /// Initialize with audio file
    /// - Parameter audioFile: AVAudioFile to start with
    public init(audioFile: AVAudioFile) {
        self.audioFile = audioFile
    }

    /// Initialize with URL
    /// - Parameter url: URL of audio file
    /// - Throws: Error if URL doesn't point to an audio file
    public init(url: URL) throws {
        audioFile = try AVAudioFile(forReading: url)
    }

    deinit {
        audioFile = nil
    }


    /// Abort getting the waveform data
    public func cancel(offset: Int) {
        abortGetWaveformData[offset] = true
    }
    
    public func getFrame(offset: Int = 0,
                         zoom: CGFloat) -> [Float]?
    {
        guard offset >= 0 else { return nil }
        
        let cacheKey = CacheKey(offset: offset, zoom: zoom)
        if let data =  waveformCache[cacheKey] {
            return data
        }
        
        guard let audioFile = audioFile else { return nil }
        
        
        let frameSize = Int(1024 * zoom)
        let samplesPerFrame = 64
  
        // store the current frame
        let currentFrame = audioFile.framePosition
        
        let totalFrameCount = AVAudioFrameCount(audioFile.length)
        var framesPerBuffer: AVAudioFrameCount = totalFrameCount / AVAudioFrameCount(frameSize)
   
        
        if tileSize != framesPerBuffer * UInt32(samplesPerFrame) {
            tileSize = framesPerBuffer * UInt32(samplesPerFrame)
        }
        
        // set peak value if nil
        if peakValue == nil {
            peakValue = audioFile.toAVAudioPCMBuffer()?.peak()?.amplitude
        }
        
        guard let rmsBuffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat,
                                               frameCapacity: AVAudioFrameCount(framesPerBuffer)) else { return nil }

        

       
        
        let channelCount = Int(audioFile.processingFormat.channelCount)
        var data = Array(repeating: Float.zero, count: samplesPerFrame)

        var start: Int = offset
        var end = samplesPerFrame
        var startFrame: AVAudioFramePosition = Int64(start * samplesPerFrame * Int(framesPerBuffer))

        if startFrame  > totalFrameCount {
            return nil
        }
        
        
//        if UInt32(startFrame) + (samplesPerFrame * framesPerBuffer) > totalFrameCount {
//            let difference = UInt32(startFrame) + (samplesPerFrame * framesPerBuffer) - totalFrameCount
//            end -= difference
//
//            print("XCEEDD\n\n\n\n\n\n\n", difference / framesPerBuffer)
////            end = //
//        }
//
//        print("totalFrameCount", totalFrameCount)
//        print("startFrame", startFrame)
//

        for i in 0 ..< end {
            if abortGetWaveformData[offset] ?? false {
                // return the file to frame is was on previously
                audioFile.framePosition = currentFrame
                abortGetWaveformData[offset] = false
                return nil
            }

            do {
                audioFile.framePosition = startFrame
                try audioFile.read(into: rmsBuffer, frameCount: framesPerBuffer)

            } catch let err as NSError {
                return nil
            }

            guard let floatData = rmsBuffer.floatChannelData else { return nil }

            var channelAccumulator: Float = 0
            for channel in 0 ..< channelCount {
                var rms: Float = 0.0
                vDSP_rmsqv(floatData[channel], 1, &rms, vDSP_Length(rmsBuffer.frameLength))
                channelAccumulator += rms
            }

            channelAccumulator = channelAccumulator / Float(channelCount)
            
            if let peakValue {
                channelAccumulator = channelAccumulator / peakValue
            }

            data[i] = channelAccumulator
            
            startFrame += AVAudioFramePosition(framesPerBuffer)

            
            if startFrame + AVAudioFramePosition(framesPerBuffer) > totalFrameCount {
                break
//                let subtraction = totalFrameCount.subtractingReportingOverflow(AVAudioFrameCount(startFrame))
//                framesPerBuffer = subtraction.partialValue
//                if framesPerBuffer <= 0 { break }
            }
        }

        // return the file to frame is was on previously
        audioFile.framePosition = currentFrame

        
        waveformCache[cacheKey] = data
        return data
    }

}


/// Request to get data out of an audio file
public class WaveformRequest2 {
    /// Audio file get data from
    public private(set) var audioBuffer: AVAudioPCMBuffer
    
    var peakValue: Float? = nil
    var tileSize: UInt32? = nil

    struct CacheKey: Hashable {
        let offset: Int
        let zoom: CGFloat
    }
    
    private var waveformCache: [CacheKey: [Float]] = [:]

    
    private let abortWaveformDataQueue = DispatchQueue(label: "WaveformDataRequest.abortWaveformDataQueue",
                                                       attributes: .concurrent)

    private var _abortGetWaveformData: [Int: Bool] = [:]
    /// Should we abort the waveform data
    public var abortGetWaveformData: [Int: Bool] {
        get { _abortGetWaveformData }
        set {
            abortWaveformDataQueue.async(flags: .barrier) {
                self._abortGetWaveformData = newValue
            }
        }
    }
    


    /// Initialize with URL
    /// - Parameter url: URL of audio file
    /// - Throws: Error if URL doesn't point to an audio file
    public init(audioBuffer: AVAudioPCMBuffer) {
        self.audioBuffer = audioBuffer
    }


    /// Abort getting the waveform data
    public func cancel(offset: Int) {
        abortGetWaveformData[offset] = true
    }
    
    public func getFrame(offset: Int = 0,
                         zoom: CGFloat) -> [Float]?
    {
        
        guard offset >= 0 else {
            print("OFFSET MUST BE GREATER OR EQUAL TO 0")
            return nil
        }
        
        let cacheKey = CacheKey(offset: offset, zoom: zoom)
        if let data =  waveformCache[cacheKey] {
            return data
        }
        
        
        let sampleRate = audioBuffer.format.sampleRate
        let frameSize: CGFloat = CGFloat(64) * zoom
        let samplesPerTile = 64
  
        
        let totalFrameCount = audioBuffer.frameLength
        var framesPerBuffer: CGFloat = CGFloat(totalFrameCount) / frameSize

        // set peak value if nil
        if peakValue == nil {
            peakValue = audioBuffer.peak()?.amplitude
        }
        
        guard let rmsBuffer = AVAudioPCMBuffer(pcmFormat: audioBuffer.format,
                                               frameCapacity: AVAudioFrameCount(framesPerBuffer)) else {
            print("COULDNT CREATE RMS BUFFER")
            return nil
        }
        
        let channelCount = Int(audioBuffer.format.channelCount)
        var data = Array(repeating: Float.zero, count: samplesPerTile)

        var startFrame: AVAudioFramePosition = AVAudioFramePosition(AVAudioFrameCount(offset) * AVAudioFrameCount(samplesPerTile) * AVAudioFrameCount(framesPerBuffer))

        if startFrame  > totalFrameCount {
            return nil
        }
        
 
        for i in 0 ..< samplesPerTile {
            if abortGetWaveformData[offset] ?? false {
                abortGetWaveformData[offset] = false
                print("WAVEFORM REQUEST ABORTED")

                return nil
            }
            
            let endFrame = startFrame + Int64(framesPerBuffer)
            if endFrame > totalFrameCount {
                
                break
            }
            
            let segment = segment(of: audioBuffer,
                                  from: startFrame,
                                  to: endFrame)

            guard let segment, let floatData = segment.floatChannelData else {
                print("sGMENt BUFFER HAS NO CHANNEL DATA")
                return nil
            }

            var channelAccumulator: Float = 0
            for channel in 0 ..< channelCount {
                var rms: Float = 0.0
                vDSP_rmsqv(floatData[channel], 1, &rms, vDSP_Length(segment.frameLength))
                channelAccumulator += rms
            }

            channelAccumulator = channelAccumulator / Float(channelCount)
            
            if let peakValue {
                channelAccumulator = channelAccumulator / peakValue
            }

            data[i] = channelAccumulator
            
            startFrame += Int64(framesPerBuffer)

        }
        waveformCache[cacheKey] = data
        return data
    }
    
    public func getFrame(at position: CGFloat = 0,
                         zoom: CGFloat) -> [Float]?
    {
      
        
        let frameSize = CGFloat(1024 * zoom)
        let samplesPerTile = 64
  
        
        let totalFrameCount = audioBuffer.frameLength
        let offset = CGFloat(totalFrameCount) * position
        var framesPerBuffer: CGFloat = CGFloat(totalFrameCount) / frameSize

        // set peak value if nil
        if peakValue == nil {
            peakValue = audioBuffer.peak()?.amplitude
        }
        
        guard let rmsBuffer = AVAudioPCMBuffer(pcmFormat: audioBuffer.format,
                                               frameCapacity: AVAudioFrameCount(framesPerBuffer)) else {
            print("COULDNT CREATE RMS BUFFER")
            return nil
        }
        
        let channelCount = Int(audioBuffer.format.channelCount)
        var data = Array(repeating: Float.zero, count: samplesPerTile)

        var startFrame: AVAudioFramePosition = AVAudioFramePosition(offset)
        
        if startFrame  > totalFrameCount {
            return nil
        }
        
 
        for i in 0 ..< samplesPerTile {
         
            let endFrame = startFrame + Int64(framesPerBuffer)
            if endFrame > totalFrameCount {
                
                break
            }
            
            let segment = segment(of: audioBuffer,
                                  from: startFrame,
                                  to: endFrame)

            guard let segment, let floatData = segment.floatChannelData else {
                print("sGMENt BUFFER HAS NO CHANNEL DATA")
                return nil
            }

            var channelAccumulator: Float = 0
            for channel in 0 ..< channelCount {
                var rms: Float = 0.0
                vDSP_rmsqv(floatData[channel], 1, &rms, vDSP_Length(segment.frameLength))
                channelAccumulator += rms
            }

            channelAccumulator = channelAccumulator / Float(channelCount)
            
            if let peakValue {
                channelAccumulator = channelAccumulator / peakValue
            }

            data[i] = channelAccumulator
            
            startFrame += Int64(framesPerBuffer)

        }

        return data
    }
    
    
    
    public func getBins(bins: Int = 80) -> [Float] {
        var floats = Array.init(repeating: Float.zero, count: bins)
        let totalFrameCount = AVAudioFramePosition(audioBuffer.frameLength)
        let framesPerBin = totalFrameCount / AVAudioFramePosition(bins)
        
        let channelCount = audioBuffer.format.channelCount
        
        if peakValue == nil {
            peakValue = audioBuffer.peak()?.amplitude
        }
        
        for i in 0..<bins {
            let start = AVAudioFramePosition(i) * framesPerBin
            let end = start + framesPerBin

            var channelAccumulator: Float = 0

            if let segment = segment(of: audioBuffer,
                                  from: start,
                                     to: end),
               let floatData = segment.toFloatChannelData() {
                for channel in 0 ..< channelCount {
                    var rms: Float = 0.0
                    vDSP_rmsqv(floatData[Int(channel)], 1, &rms, vDSP_Length(segment.frameLength))
                    channelAccumulator += rms
                }
            }
            
            channelAccumulator = channelAccumulator / Float(channelCount)
            
            if let peakValue {
                channelAccumulator = channelAccumulator / peakValue
            }
            
            floats[i] = channelAccumulator

        }
        return floats
    }
}
