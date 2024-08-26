//
//  File.swift
//  
//
//  Created by John Knowles on 7/15/24.
//

import Foundation
import Accelerate


extension Array where Element == Float {
    //  @see: HOW TO CREATE A SOUNDCLOUD LIKE WAVEFORM IN SWIFT 3
    //        (https://miguelsaldana.me/2017/03/13/how-to-create-a-soundcloud-like-waveform-in-swift-3/)
    func downSampled(binSize: Int, multiplier: Float = 1.0) -> [Float] {
        let count = self.count

        var processingBuffer = [Float](repeating: 0.0,
                                       count: Int(count))
        let sampleCount = vDSP_Length(count)

        vDSP_vabs(self, 1, &processingBuffer, 1, sampleCount)

        //THIS IS OPTIONAL
        // convert do dB
//            var zero:Float = 1;
//            vDSP_vdbcon(floatArrPtr, 1, &zero, floatArrPtr, 1, sampleCount, 1);
//            //print(floatArr)
//
//            // clip to [noiseFloor, 0]
//            var noiseFloor:Float = -50.0
//            var ceil:Float = 0.0
//            vDSP_vclip(floatArrPtr, 1, &noiseFloor, &ceil,
//                           floatArrPtr, 1, sampleCount);
        //print(floatArr)

        let numSamplesPerPixel = Int(Float(binSize) * multiplier)

        let filter = [Float](repeating: 1.0 / Float(numSamplesPerPixel),
                             count: Int(numSamplesPerPixel))
        let downSampledLength = Int(count / numSamplesPerPixel)
        var downSampledData = [Float](repeating:0.0,
                                      count:downSampledLength)
        vDSP_desamp(processingBuffer,
                    vDSP_Stride(numSamplesPerPixel),
                    filter, &downSampledData,
                    vDSP_Length(downSampledLength),
                    vDSP_Length(numSamplesPerPixel))

        // print(" DOWNSAMPLEDDATA: \(downSampledData.count)")

        return downSampledData
    }

    func downSampled(numBins: Int, multiplier: Float = 1.0) -> [Float] {
        let numSamplesPerPixel = Int(Float(self.count) / Float(numBins) * multiplier)

        return downSampled(binSize: numSamplesPerPixel, multiplier: 1.0)
    }
}


