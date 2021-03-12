//
//  WRSHardCode.swift
//  WRSLiveStreaming
//
//  Created by jack on 2021/3/9.
//

import Foundation
import VideoToolbox
public protocol WRSHardVideoEncoderDelegate: NSObjectProtocol {
    func videoEncoder(encoder: WRSHardVideoEncoder, didGetSps: Data, pps: Data, timeStamp: UInt64);
    func videoEncoder(encoder: WRSHardVideoEncoder, didEncoderFrame: Data, timeStamp: UInt64, isKeyFrame: Bool);
}

public class WRSHardVideoEncoder {
    var compressionSession: VTCompressionSession?
    var frameCount: Int = 0
    var videoFrameRate = 24
    var maxKeyframeInterval = 10
    var sps: Data? // Sequence Paramater Set，又称作序列参数集。SPS中保存了一组编码视频序列(Coded video sequence)的全局参数
    var pps: Data?
    var width: Int32 = 640
    var height: Int32 = 320
    var delegate: WRSHardVideoEncoderDelegate?
    
    private var compressioinOutputCallback: VTCompressionOutputCallback?
    
    deinit {
        deinitCompressionSession()
    }
    
    init(width: Int32, height: Int32) {
        self.width = width
        self.height = height
        self.compressioinOutputCallback  = { (VTref: UnsafeMutableRawPointer?, VTFrameRef: UnsafeMutableRawPointer?, status: OSStatus, infoFlags: VTEncodeInfoFlags, sampleBuffer: CMSampleBuffer?) in
            if let tempEncoder = VTref, let tempTimestamp = VTFrameRef, let buffer = sampleBuffer {
                if status != noErr { // 有错直接return
                    return;
                }
//                let sampleData =  NSMutableData()
                let naluStart:[UInt8] = [0x00, 0x00, 0x00, 0x01]
                let naluStart1:[UInt8] = [0x00, 0x00, 0x01]
                
                let videoEncoder:WRSHardVideoEncoder = unsafeBitCast(tempEncoder, to: WRSHardVideoEncoder.self)
                let timestamp:UInt64 = UInt64(UInt(bitPattern: tempTimestamp))
                let isKeyframe = !CFDictionaryContainsKey(unsafeBitCast(CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: true), 0), to: CFDictionary.self), unsafeBitCast(kCMSampleAttachmentKey_NotSync, to: UnsafeRawPointer.self))
                if isKeyframe && videoEncoder.sps != nil { // 是的话，CMVideoFormatDescriptionGetH264ParameterSetAtIndex获取sps和pps信息，并转换为二进制写入文件或者进行上传
                    if let format: CMFormatDescription = CMSampleBufferGetFormatDescription(buffer) {
                        let sps = UnsafeMutablePointer<UnsafePointer<UInt8>?>.allocate(capacity: 1)
                        let spsLength = UnsafeMutablePointer<Int>.allocate(capacity: 1)
                        let spsCount = UnsafeMutablePointer<Int>.allocate(capacity: 1)
                        sps.initialize(to: nil)
                        spsLength.initialize(to: 0)
                        spsCount.initialize(to: 0)
                        let spsStatus: OSStatus = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, parameterSetIndex: 0, parameterSetPointerOut: sps, parameterSetSizeOut: spsLength, parameterSetCountOut: spsCount, nalUnitHeaderLengthOut: nil)
                        if spsStatus == noErr {
                            let pps = UnsafeMutablePointer<UnsafePointer<UInt8>?>.allocate(capacity: 1)
                            let ppsLength = UnsafeMutablePointer<Int>.allocate(capacity: 1)
                            let ppsCount = UnsafeMutablePointer<Int>.allocate(capacity: 1)
                            pps.initialize(to: nil)
                            ppsLength.initialize(to: 0)
                            ppsCount.initialize(to: 0)
                            let ppsStatus: OSStatus = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, parameterSetIndex: 1, parameterSetPointerOut: pps, parameterSetSizeOut: ppsLength, parameterSetCountOut: ppsCount, nalUnitHeaderLengthOut: nil)
                            if ppsStatus == noErr {
                                if let spsPointee = sps.pointee, let ppsPointee = pps.pointee {
                                    let spsData = Data(bytes: spsPointee, count: spsLength.pointee)
                                    let ppsData = Data(bytes: ppsPointee, count: ppsLength.pointee)
                                    if let tempDelegate = videoEncoder.delegate {
                                        tempDelegate.videoEncoder(encoder: videoEncoder, didGetSps: spsData, pps: ppsData, timeStamp: timestamp)
                                    }
//                                    sampleData.append(naluStart, length: naluStart.count)
//                                    sampleData.append(spsPointee, length: spsLength.pointee)
//                                    sampleData.append(naluStart, length: naluStart.count)
//                                    sampleData.append(ppsPointee, length: ppsLength.pointee)
                                }
                            }
                            
                            pps.deallocate()
                            ppsLength.deallocate()
                            ppsCount.deallocate()
                            pps.deinitialize(count: 1)
                            ppsLength.deinitialize(count: 1)
                            ppsCount.deinitialize(count: 1)
                            
                            
                            
                        }
                        
                        sps.deallocate()
                        spsLength.deallocate()
                        spsCount.deallocate()
                        sps.deinitialize(count: 1)
                        spsLength.deinitialize(count: 1)
                        spsCount.deinitialize(count: 1)
                        
                    }

                }
                
                if let blockBuffer: CMBlockBuffer = CMSampleBufferGetDataBuffer(buffer) {
                    var totalLength = Int()
                    var length = Int()
                    var dataPointer: UnsafeMutablePointer<Int8>? = nil
                    let state: OSStatus = CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: &length, totalLengthOut: &totalLength, dataPointerOut: &dataPointer)
                    if state == noErr {
                        if let tempDataPointer = dataPointer {
                            var bufferOffset = 0;
                            let AVCCHeaderLength = 4
                            while bufferOffset < totalLength - AVCCHeaderLength {
                                var NALUnitLength:UInt32 = 0
                                memcpy(&NALUnitLength, tempDataPointer + bufferOffset, AVCCHeaderLength)
                                NALUnitLength = CFSwapInt32BigToHost(NALUnitLength)
                                
                                let frameData = Data(bytes: tempDataPointer + bufferOffset + AVCCHeaderLength, count: Int(NALUnitLength))
                                if let tempDelegate = videoEncoder.delegate {
                                    tempDelegate.videoEncoder(encoder: videoEncoder, didEncoderFrame: frameData, timeStamp: timestamp, isKeyFrame: isKeyframe)
                                }
//                                if isKeyframe {
//                                    sampleData.append(naluStart, length: naluStart.count)
//                                } else {
//                                    sampleData.append(naluStart1, length: naluStart1.count)
//                                }
//                                sampleData.append(tempDataPointer + bufferOffset + AVCCHeaderLength, length: Int(NALUnitLength))
                                
                                bufferOffset += (AVCCHeaderLength + Int(NALUnitLength))
//                                var naluStart:[UInt8] = [UInt8](count: 4, repeatedValue: 0x00)
//                                naluStart[3] = 0x01
//                                let buffer:NSMutableData = NSMutableData()
//                                buffer.appendBytes(&naluStart, length: naluStart.count)
//                                buffer.appendBytes(dataPointer + bufferOffset + AVCCHeaderLength, length: Int(NALUnitLength))
//                                fileHandle.writeData(buffer)
//                                bufferOffset += (AVCCHeaderLength + Int(NALUnitLength))
                            }
                        }
                    }
                }
            }
        }
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
        // allocator  分配器,设置为默认分配
        // width 宽
        // height 高
        // encoderSpecification 编码规范,设置nil由videoToolbox自己选择
        // imageBufferAttributes 源像素缓冲区属性.设置nil不让videToolbox创建,而自己创建
        // compressedDataAllocator 压缩数据分配器.设置nil,默认的分配
        // outputCallback 编码回调
        // refcon 回调客户定义的参考值，此处把self传过去，因为我们需要在C函数中调用self的方法，而C函数无法直接调self
        // compressionSessionOut 编码会话
        let status: OSStatus = VTCompressionSessionCreate(allocator: kCFAllocatorDefault, width: width, height: height, codecType: kCMVideoCodecType_H264, encoderSpecification: nil, imageBufferAttributes: nil, compressedDataAllocator: nil, outputCallback: self.compressioinOutputCallback, refcon: unsafeBitCast(self, to: UnsafeMutableRawPointer.self), compressionSessionOut: &self.compressionSession)
        if status != noErr {
            return
        }
        if let tempCompressionSession = self.compressionSession {
            
            //设置关键帧（GOPsize）间隔，GOP太小的话图像会模糊
            let maxKeyFrameInterval = CFNumberCreate(kCFAllocatorDefault, CFNumberType.intType, &maxKeyframeInterval)
            VTSessionSetProperty(tempCompressionSession, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: maxKeyFrameInterval)

            // 最大帧率间隔
            var maxKeyFrameIntervalDurationValue = maxKeyframeInterval / videoFrameRate
            let maxKeyFrameIntervalDuration = CFNumberCreate(kCFAllocatorDefault, CFNumberType.intType, &maxKeyFrameIntervalDurationValue)
            VTSessionSetProperty(tempCompressionSession, key: kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, value: maxKeyFrameIntervalDuration)
            
            //设置期望帧率，不是实际帧率
            VTSessionSetProperty(tempCompressionSession, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: maxKeyFrameIntervalDuration)
            
            // 码率，码率大了话就会非常清晰，但同时文件也会比较大。码率小的话，图像有时会模糊，但也勉强能看
            var bitRate = 800*1024
            let averageBitRate = CFNumberCreate(kCFAllocatorDefault, CFNumberType.intType, &bitRate)
            VTSessionSetProperty(tempCompressionSession, key: kVTCompressionPropertyKey_AverageBitRate, value: averageBitRate)
            
            // CFNumberCreate(_ allocator: CFAllocator!, _ theType: CFNumberType, _ valuePtr: UnsafeRawPointer!) -> CFNumber!
            var array: Array = [NSNumber(value: Double(bitRate) * 1.5 / 8), NSNumber(value: 1)]
//            CFArrayCreate(kCFAllocatorDefault, array as CFArray, <#T##numValues: CFIndex##CFIndex#>, <#T##callBacks: UnsafePointer<CFArrayCallBacks>!##UnsafePointer<CFArrayCallBacks>?#>)
//            let averageBitRate = withUnsafeMutablePointer(to: &array) { ppArray in
//                CFArrayCreate(kCFAllocatorDefault, ppArray, ppArray.count, nil)
//            }
//            CFArrayCreate(_ allocator: CFAllocator!, _ values: UnsafeMutablePointer<UnsafeRawPointer?>!, _ numValues: CFIndex, _ callBacks: UnsafePointer<CFArrayCallBacks>!) -> CFArray
//            var windowsPointer = UnsafeMutablePointer<UnsafeRawPointer>(array)
//            let averageBitRate = CFArrayCreate(kCFAllocatorDefault, windowsPointer, array.count, nil)
//            VTSessionSetProperty(tempCompressionSession, key: kVTCompressionPropertyKey_DataRateLimits, value: array)
            
            //设置实时编码输出（避免延迟）
            VTSessionSetProperty(tempCompressionSession, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue);
            VTSessionSetProperty(tempCompressionSession, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Main_AutoLevel);
            
            //是否产生B帧(因为B帧在解码时并不是必要的,是可以抛弃B帧的)
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
          
            // imageBuffer 未编码的数据
            // presentationTimeStamp 获取到的这个sample buffer数据的展示时间戳。每一个传给这个session的时间戳都要大于前一个展示时间戳
            // duration 对于获取到sample buffer数据,这个帧的展示时间.如果没有时间信息,可设置kCMTimeInvalid.
            // frameProperties 包含这个帧的属性.帧的改变会影响后边的编码帧.
            // sourceFrameRefcon 回调函数会引用你设置的这个帧的参考值.
            // infoFlagsOut 指向一个VTEncodeInfoFlags来接受一个编码操作.如果使用异步运行,kVTEncodeInfo_Asynchronous被设置；同步运行,kVTEncodeInfo_FrameDropped被设置；设置NULL为不想接受这个信息.
            let status: OSStatus = VTCompressionSessionEncodeFrame(tempCompressionSession, imageBuffer: pixelBuffer, presentationTimeStamp: presentationTimeStamp, duration: duration, frameProperties: properties as CFDictionary?, sourceFrameRefcon: &timeNumber, infoFlagsOut: nil)
            if status != noErr{ // 编码失败时重置编码器
                self.resetCompressionSession()
            }
        }
    }
    
    func videoCompressonOutputCallback(VTref: UnsafeMutableRawPointer?, VTFrameRef: UnsafeMutableRawPointer?, status: OSStatus, infoFlags: VTEncodeInfoFlags, sampleBuffer: CMSampleBuffer?) -> Void {
        
    }
}
