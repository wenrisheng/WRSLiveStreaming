//
//  WRSHardCode.swift
//  WRSLiveStreaming
//
//  Created by jack on 2021/3/9.
//

import Foundation
import VideoToolbox

public class WRSHardVideoCode {
    var compressionSession: VTCompressionSession?
    var frameCount: Int = 0
    var videoFrameRate = 24
    var maxKeyframeInterval = 10
    var sps: Data? // Sequence Paramater Set，又称作序列参数集。SPS中保存了一组编码视频序列(Coded video sequence)的全局参数
    var pps: Data?
    var width: Int32 = 640
    var height: Int32 = 320
    deinit {
        deinitCompressionSession()
    }
    
    init(width: Int32, height: Int32) {
        self.width = width
        self.height = height
        resetCompressionSession()
    }
    
    func deinitCompressionSession() -> Void {
        if let tempCompressionSession = self.compressionSession {
            VTCompressionSessionCompleteFrames(tempCompressionSession, untilPresentationTimeStamp: CMTime.invalid)
            VTCompressionSessionInvalidate(tempCompressionSession)
            self.compressionSession = nil
        }
    }
    
    func resetCompressionSession() -> Void {
        deinitCompressionSession()
        let status: OSStatus = VTCompressionSessionCreate(allocator: kCFAllocatorDefault, width: width, height: height, codecType: kCMVideoCodecType_H264, encoderSpecification: nil, imageBufferAttributes: nil, compressedDataAllocator: nil, outputCallback: { (VTref: UnsafeMutableRawPointer?, VTFrameRef: UnsafeMutableRawPointer?, status: OSStatus, infoFlags: VTEncodeInfoFlags, sampleBuffer: CMSampleBuffer?) in
            
        }, refcon: unsafeBitCast(self, to: UnsafeMutableRawPointer.self), compressionSessionOut: &self.compressionSession)
        if status != noErr {
            return
        }
        if let tempCompressionSession = self.compressionSession {
            
            //设置关键帧间隔
            let maxKeyFrameInterval = CFNumberCreate(kCFAllocatorDefault, CFNumberType.intType, &maxKeyframeInterval)
            VTSessionSetProperty(tempCompressionSession, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: maxKeyFrameInterval)

            // 最大帧率间隔
            var maxKeyFrameIntervalDurationValue = maxKeyframeInterval / videoFrameRate
            let maxKeyFrameIntervalDuration = CFNumberCreate(kCFAllocatorDefault, CFNumberType.intType, &maxKeyFrameIntervalDurationValue)
            VTSessionSetProperty(tempCompressionSession, key: kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, value: maxKeyFrameIntervalDuration)
            
            // 期望帧率
            VTSessionSetProperty(tempCompressionSession, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: maxKeyFrameIntervalDuration)
            
            // 码率
            var bitRate = 800*1024
            let averageBitRate = CFNumberCreate(kCFAllocatorDefault, CFNumberType.intType, &bitRate)
            VTSessionSetProperty(tempCompressionSession, key: kVTCompressionPropertyKey_AverageBitRate, value: averageBitRate)
            
            // CFNumberCreate(_ allocator: CFAllocator!, _ theType: CFNumberType, _ valuePtr: UnsafeRawPointer!) -> CFNumber!
//            var array: [NSNumber] = [NSNumber(value: Double(bitRate) * 1.5 / 8), NSNumber(value: 1)]
//            let averageBitRate = withUnsafeMutablePointer(to: &array) { ppArray in
//                CFArrayCreate(kCFAllocatorDefault, ppArray, ppArray.count, nil)
//            }
//            CFArrayCreate(_ allocator: CFAllocator!, _ values: UnsafeMutablePointer<UnsafeRawPointer?>!, _ numValues: CFIndex, _ callBacks: UnsafePointer<CFArrayCallBacks>!) -> CFArray
//            var windowsPointer = UnsafeMutablePointer<UnsafeRawPointer>(array)
//            let averageBitRate = CFArrayCreate(kCFAllocatorDefault, windowsPointer, array.count, nil)
//            VTSessionSetProperty(tempCompressionSession, key: kVTCompressionPropertyKey_DataRateLimits, value: averageBitRate)
            
            VTSessionSetProperty(tempCompressionSession, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue);
            VTSessionSetProperty(tempCompressionSession, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Main_AutoLevel);
            VTSessionSetProperty(tempCompressionSession, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanTrue);
            VTSessionSetProperty(tempCompressionSession, key: kVTCompressionPropertyKey_H264EntropyMode, value: kVTH264EntropyMode_CABAC);
            VTCompressionSessionPrepareToEncodeFrames(tempCompressionSession);

        }
    }
    
    func encodeVideoData(pixelBuffer: CVImageBuffer, timeStamp: UInt64) -> Void {
        if let tempCompressionSession = self.compressionSession {
            frameCount += 1
            let presentationTimeStamp: CMTime = CMTime(value: CMTimeValue(frameCount), timescale: CMTimeScale(videoFrameRate))
            let duration: CMTime = CMTime(value: CMTimeValue(1), timescale: CMTimeScale(videoFrameRate))
            var properties: Dictionary<String, Any>?
            if (frameCount % maxKeyframeInterval == 0) {
                properties = [
                    kVTEncodeFrameOptionKey_ForceKeyFrame as String: true
                ];
            }
            var timeNumber = timeStamp
//            var flags:VTEncodeInfoFlags?
//            VTCompressionSessionEncodeFrame(<#T##session: VTCompressionSession##VTCompressionSession#>, imageBuffer: CVImageBuffer, presentationTimeStamp: <#T##CMTime#>, duration: <#T##CMTime#>, frameProperties: <#T##CFDictionary?#>, sourceFrameRefcon: T##UnsafeMutableRawPointer?, infoFlagsOut: <#T##UnsafeMutablePointer<VTEncodeInfoFlags>?#>)
            let status: OSStatus = VTCompressionSessionEncodeFrame(tempCompressionSession, imageBuffer: pixelBuffer, presentationTimeStamp: presentationTimeStamp, duration: duration, frameProperties: properties as CFDictionary?, sourceFrameRefcon: &timeNumber, infoFlagsOut: nil)
            if status != noErr{
                self.resetCompressionSession()
            }
        }

    }
}
