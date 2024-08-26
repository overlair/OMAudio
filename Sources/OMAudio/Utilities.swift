//
//  File.swift
//  
//
//  Created by John Knowles on 7/15/24.
//

import Foundation
import Accelerate
import AVFoundation
import AudioKit



extension Array where Element == Float {
    //  @see: HOW TO CREATE A SOUNDCLOUD LIKE WAVEFORM IN SWIFT 3
    //        (https://miguelsaldana.me/2017/03/13/how-to-create-a-soundcloud-like-waveform-in-swift-3/)
    func downSampled(binSize: Int, multiplier: Float = 1.0) -> [Float] {
        let count = self.count

        var processingBuffer = [Float](repeating: 0.0,
                                       count: Int(count))
        let sampleCount = vDSP_Length(count)

//        vDSP_vabs(self, 1, &processingBuffer, 1, sampleCount)

        //THIS IS OPTIONAL
        // convert do dB
        var dbBuffer = [Float](repeating: 0.0,
                                       count: Int(count))

            var zero:Float = 0;
            vDSP_vdbcon(self, 1, &zero, &dbBuffer, 1, sampleCount, 1);
            //print(floatArr)

            // clip to [noiseFloor, 0]
        var flooredBuffer = [Float](repeating: 0.0,
                                       count: Int(count))

            var noiseFloor:Float = -50.0
            var ceil:Float = 0.0
            vDSP_vclip(dbBuffer, 1, &noiseFloor, &ceil,
                       &flooredBuffer, 1, sampleCount);
        //print(floatArr)

        let numSamplesPerPixel = Int(Float(binSize) * multiplier)

        let filter = [Float](repeating: 1.0 / Float(numSamplesPerPixel),
                             count: Int(numSamplesPerPixel))
        let downSampledLength = Int(count / numSamplesPerPixel)
        var downSampledData = [Float](repeating:0.0,
                                      count:downSampledLength)
        vDSP_desamp(flooredBuffer,
                    vDSP_Stride(numSamplesPerPixel),
                    filter, 
                    &downSampledData,
                    vDSP_Length(downSampledLength),
                    vDSP_Length(numSamplesPerPixel))

        // print(" DOWNSAMPLEDDATA: \(downSampledData.count)")

        return downSampledData
    }

    func downSampled(numBins: Int, multiplier: Float = 1.0) -> [Float] {
        let numSamplesPerPixel = Int(Float(self.count) / Float(numBins) * multiplier)

        return downSampled(binSize: numSamplesPerPixel, multiplier: 1.0)
    }
    
    
    
    func downsample(numBins: Int) -> [Float] {
        let samples = self
        let count = samples.count
        let numSamplesPerPixel = Int(Float(count) / Float(numBins))
        
        var processingBuffer = [Float](repeating: 0.0, count: Int(count))
                                       

        var filter = [Float](repeating: 1.0 / Float(numSamplesPerPixel), count: Int(numSamplesPerPixel))

        let sampleCount = vDSP_Length(count)
          
//        // convert the 16bit int samples to floats
//        vDSP_vflt16(samples, 1, &processingBuffer, 1, sampleCount)
          
        // take the absolute values to get amplitude
        vDSP_vabs(self, 1, &processingBuffer, 1, sampleCount);

        // convert do dB
        var zero:Float = 1;
        vDSP_vdbcon(processingBuffer, 1, &zero, &processingBuffer, 1,
                    sampleCount, 1);

        // clip to [noiseFloor, 0]
        var noiseFloor:Float = -40.0
        var _noiseFloor:Float = -1 * noiseFloor
        var ceil:Float = 0.0
        vDSP_vclip(processingBuffer, 1, &noiseFloor, &ceil,
                   &processingBuffer, 1, sampleCount);

        // downsample and average
        var downSampledLength = Int(count / numSamplesPerPixel)
        var downSampledData = [Float](repeating: 0.0, count:downSampledLength)
          
        vDSP_desamp(processingBuffer,
                      vDSP_Stride(numSamplesPerPixel),
                      filter, &downSampledData,
                      vDSP_Length(downSampledLength),
                      vDSP_Length(numSamplesPerPixel))
        
        return vDSP.add(-noiseFloor, downSampledData)
                      
    }
}

extension AVAudioFile {
    
    func convert()  {
        let path = self.url
        
        var options = FormatConverter.Options()

        // any options left nil will adopt the value of the input file
        options.format = .m4a
        options.sampleRate = 24000
        options.isInterleaved = false
//        options.bitDepth = 24

        let converter = FormatConverter(inputURL: path,
                                        outputURL: path,
                                        options: options)
        
        converter.start(completionHandler: { error in
            print(error)
        })
        
    }
}



struct ShowableFloat: Identifiable, Equatable {
    let id: Int
    let scale: CGFloat
}

extension FloatChannelData {
    func showable() -> [ShowableFloat] {
        guard let first = self.first else {
            return []
        }
        
        let downsampled = first.downSampled(numBins: 100)
        var showables = [ShowableFloat]()
        for sample in 0..<downsampled.count {
            showables.append(.init(id: sample, scale: CGFloat(downsampled[sample])))
        }
        return showables
    }
}


extension [Float] {
    func showable() -> [ShowableFloat] {
        
        //        let downsampled = self.downSampled(numBins: 100)
        var showables = [ShowableFloat]()
        for sample in 0..<self.count {
            showables.append(.init(id: sample, scale: CGFloat(self[sample])))
        }
        return showables
    }
}

extension Double {
    func timeLabel() -> String {
        var label: String
        let duration = Int(self)
        if duration > 60 * 60 {
            let hour = Int(duration / 60)
            let minute = Int(hour / 60)
            let second = Int(duration) - (minute * 60) - (hour * 60 * 60)
            let _hour = String(format: "%0.2d", minute)
            let _minute = String(format: "%0.2d", minute)
            let _second = String(format: "%0.2d", second)
            label = _hour + ":" + _minute + ":" + _second
            
        } else if duration > 60 {
            let minute = Int(duration / 60)
            let second = Int(duration) - minute * 60
            let _minute = String(format: "%0.2d", minute)
            let _second = String(format: "%0.2d", second)
            label =  _minute + ":" + _second
        } else {
            let _second = String(format: "%0.2d", Int(duration))
            label = "00:" + _second
        }
        
        return label
    }
    
}


enum PCMBufferError: Error {
    case urlIsNotValid
    
    case failedToInitializeAVAudioFile
    case failedToReadAVAudioFile
    
    case failedToReadInputPath
    case failedToObtainInputBuffer
    case failedToObtainOutputBuffer
    case failedToCreateWriteBuffer
    case failedToCreateReadBuffer
    case failedToWriteToOutputBuffer
}


func segment(of buffer: AVAudioPCMBuffer, from startFrame: AVAudioFramePosition, to endFrame: AVAudioFramePosition) -> AVAudioPCMBuffer? {
    let framesToCopy = AVAudioFrameCount(endFrame - startFrame)
    guard let segment = AVAudioPCMBuffer(pcmFormat: buffer.format,
                                         frameCapacity: framesToCopy)
    else { return nil }

    let sampleSize = buffer.format.streamDescription.pointee.mBytesPerFrame

    let srcPtr = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
    let dstPtr = UnsafeMutableAudioBufferListPointer(segment.mutableAudioBufferList)
    for (src, dst) in zip(srcPtr, dstPtr) {
        memcpy(dst.mData, src.mData?.advanced(by: Int(startFrame) * Int(sampleSize)), Int(framesToCopy) * Int(sampleSize))
    }

    segment.frameLength = framesToCopy
    return segment
}


func readPCMBuffer(input: AVAudioFile, interleaved: Bool = false) throws -> AVAudioPCMBuffer {

    print("INPUT LENGTH", input.length)
    print("INPUT URL", input.url)
    let frames = AVAudioFrameCount(input.length)
    
    guard let buffer = AVAudioPCMBuffer(pcmFormat: input.fileFormat,
                                        frameCapacity: frames) else {

        throw PCMBufferError.failedToCreateReadBuffer
    }
    
    do {
        try input.read(into: buffer, frameCount: frames)
    } catch {
        throw PCMBufferError.failedToReadAVAudioFile
    }

    return buffer
}


public func readPCMBuffer(url: URL, format: AVAudioCommonFormat = .pcmFormatInt16, interleaved: Bool = false) throws -> AVAudioPCMBuffer {
    guard let input = try? AVAudioFile(forReading: url,
                                       commonFormat: format,
                                       interleaved: interleaved) else {
        throw PCMBufferError.failedToInitializeAVAudioFile
    }
    
    print("INPUT LENGTH", input.length)
    
    guard let buffer = AVAudioPCMBuffer(pcmFormat: input.processingFormat,
                                        frameCapacity: AVAudioFrameCount(input.length)) else {

        throw PCMBufferError.failedToCreateReadBuffer
    }
    
    do {
        try input.read(into: buffer)
    } catch {
        throw PCMBufferError.failedToReadAVAudioFile
    }

    return buffer
}


public func writePCMBuffer(url: URL, buffer: AVAudioPCMBuffer) throws {
    let settings: [String: Any] = [
        AVFormatIDKey: buffer.format.settings[AVFormatIDKey] ?? kAudioFormatLinearPCM,
        AVNumberOfChannelsKey: buffer.format.settings[AVNumberOfChannelsKey] ?? 2,
        AVSampleRateKey: buffer.format.settings[AVSampleRateKey] ?? 44100,
        AVLinearPCMBitDepthKey: buffer.format.settings[AVLinearPCMBitDepthKey] ?? 32
    ]

    do {
        let output = try AVAudioFile(forWriting: url,
                                     settings: settings,
                                     commonFormat: buffer.format.commonFormat,
                                     interleaved: false)
        try output.write(from: buffer)
    } catch {
        throw error
    }
}

public func copyPCMBuffer(from inputPath: String, format: AVAudioCommonFormat, to outputPath: String) throws {
    
    guard let url = URL(string: inputPath) else {
        throw PCMBufferError.urlIsNotValid
    }
    let inputBuffer = try readPCMBuffer(url: URL(string: inputPath)!, format: format)
    
    guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: inputBuffer.format, frameCapacity: inputBuffer.frameLength) else {
        throw PCMBufferError.failedToCreateWriteBuffer
    }
    
    switch format {
    case .pcmFormatInt32:
        guard let inputInt32ChannelData = inputBuffer.int32ChannelData else {
            throw PCMBufferError.failedToObtainInputBuffer
        }
        guard let outputInt32ChannelData = outputBuffer.int32ChannelData else {
            throw PCMBufferError.failedToObtainOutputBuffer
        }
        
        for channel in 0 ..< Int(inputBuffer.format.channelCount) {
            let p1: UnsafeMutablePointer<Int32> = inputInt32ChannelData[channel]
            let p2: UnsafeMutablePointer<Int32> = outputInt32ChannelData[channel]

            for i in 0 ..< Int(inputBuffer.frameLength) {
                p2[i] = p1[i]
            }
        }
    case .pcmFormatInt16:
        guard let inputInt16ChannelData = inputBuffer.int16ChannelData else {
            throw PCMBufferError.failedToObtainInputBuffer
        }
        guard let outputInt16ChannelData = outputBuffer.int16ChannelData else {
            throw PCMBufferError.failedToObtainOutputBuffer
        }
        
        for channel in 0 ..< Int(inputBuffer.format.channelCount) {
            let p1: UnsafeMutablePointer<Int16> = inputInt16ChannelData[channel]
            let p2: UnsafeMutablePointer<Int16> = outputInt16ChannelData[channel]

            for i in 0 ..< Int(inputBuffer.frameLength) {
                p2[i] = p1[i]
            }
        }
    case .pcmFormatFloat32:
        guard let inputFloatChannelData = inputBuffer.floatChannelData else {
            throw PCMBufferError.failedToObtainInputBuffer
        }
        guard let outputFloatChannelData = outputBuffer.floatChannelData else {
            throw PCMBufferError.failedToObtainOutputBuffer
        }
        
        for channel in 0 ..< Int(inputBuffer.format.channelCount) {
            let p1: UnsafeMutablePointer<Float32> = inputFloatChannelData[channel]
            let p2: UnsafeMutablePointer<Float32> = outputFloatChannelData[channel]

            for i in 0 ..< Int(inputBuffer.frameLength) {
                p2[i] = p1[i]
            }
        }
        
    default:
        guard let inputFloatChannelData = inputBuffer.floatChannelData else {
            throw PCMBufferError.failedToObtainInputBuffer
        }
        guard let outputFloatChannelData = outputBuffer.floatChannelData else {
            throw PCMBufferError.failedToObtainOutputBuffer
        }
        
        for channel in 0 ..< Int(inputBuffer.format.channelCount) {
            let p1: UnsafeMutablePointer<Float> = inputFloatChannelData[channel]
            let p2: UnsafeMutablePointer<Float> = outputFloatChannelData[channel]

            for i in 0 ..< Int(inputBuffer.frameLength) {
                p2[i] = p1[i]
            }
        }

    }
    

    outputBuffer.frameLength = inputBuffer.frameLength

    do {
        try writePCMBuffer(url: URL(string: outputPath)!, buffer: outputBuffer)
    } catch {
        throw PCMBufferError.failedToWriteToOutputBuffer
    }
}



public func copyPCMBuffer(from file: AVAudioFile, to url: URL) throws {
    

    let inputBuffer = try readPCMBuffer(input: file)
    
    guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: inputBuffer.format, frameCapacity: inputBuffer.frameLength) else {
        throw PCMBufferError.failedToCreateWriteBuffer
    }
    
    switch inputBuffer.format.commonFormat {
    case .pcmFormatInt32:
        guard let inputInt32ChannelData = inputBuffer.int32ChannelData else {
            throw PCMBufferError.failedToObtainInputBuffer
        }
        guard let outputInt32ChannelData = outputBuffer.int32ChannelData else {
            throw PCMBufferError.failedToObtainOutputBuffer
        }
        
        for channel in 0 ..< Int(inputBuffer.format.channelCount) {
            let p1: UnsafeMutablePointer<Int32> = inputInt32ChannelData[channel]
            let p2: UnsafeMutablePointer<Int32> = outputInt32ChannelData[channel]

            for i in 0 ..< Int(inputBuffer.frameLength) {
                p2[i] = p1[i]
            }
        }
    case .pcmFormatInt16:
        guard let inputInt16ChannelData = inputBuffer.int16ChannelData else {
            throw PCMBufferError.failedToObtainInputBuffer
        }
        guard let outputInt16ChannelData = outputBuffer.int16ChannelData else {
            throw PCMBufferError.failedToObtainOutputBuffer
        }
        
        for channel in 0 ..< Int(inputBuffer.format.channelCount) {
            let p1: UnsafeMutablePointer<Int16> = inputInt16ChannelData[channel]
            let p2: UnsafeMutablePointer<Int16> = outputInt16ChannelData[channel]

            for i in 0 ..< Int(inputBuffer.frameLength) {
                p2[i] = p1[i]
            }
        }
    case .pcmFormatFloat32:
        guard let inputFloatChannelData = inputBuffer.floatChannelData else {
            throw PCMBufferError.failedToObtainInputBuffer
        }
        guard let outputFloatChannelData = outputBuffer.floatChannelData else {
            throw PCMBufferError.failedToObtainOutputBuffer
        }
        
        for channel in 0 ..< Int(inputBuffer.format.channelCount) {
            let p1: UnsafeMutablePointer<Float32> = inputFloatChannelData[channel]
            let p2: UnsafeMutablePointer<Float32> = outputFloatChannelData[channel]

            for i in 0 ..< Int(inputBuffer.frameLength) {
                p2[i] = p1[i]
            }
        }
        
    default:
        guard let inputFloatChannelData = inputBuffer.floatChannelData else {
            throw PCMBufferError.failedToObtainInputBuffer
        }
        guard let outputFloatChannelData = outputBuffer.floatChannelData else {
            throw PCMBufferError.failedToObtainOutputBuffer
        }
        
        for channel in 0 ..< Int(inputBuffer.format.channelCount) {
            let p1: UnsafeMutablePointer<Float> = inputFloatChannelData[channel]
            let p2: UnsafeMutablePointer<Float> = outputFloatChannelData[channel]

            for i in 0 ..< Int(inputBuffer.frameLength) {
                p2[i] = p1[i]
            }
        }

    }
    

    outputBuffer.frameLength = inputBuffer.frameLength

    do {
        try writePCMBuffer(url: url, buffer: outputBuffer)
    } catch {
        throw PCMBufferError.failedToWriteToOutputBuffer
    }
}
