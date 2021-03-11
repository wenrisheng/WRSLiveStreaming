//
//  WRSVideoCollect.swift
//  WRSLiveStreaming
//
//  Created by jack on 2021/3/8.
//

import Foundation
import AVFoundation
import GPUImage

public protocol WRSVideoCollectDelegate {
    func collect(collect: WRSVideoCollect, sampleBuffer: CMSampleBuffer);
}

open class WRSVideoCollect: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var session: AVCaptureSession
    var device: AVCaptureDevice?
    var videoInput: AVCaptureDeviceInput?
    var videoOutput: AVCaptureVideoDataOutput
    var videoProcessingQueue: DispatchQueue
    var collectAsYUV: Bool = true
    var delegate: WRSVideoCollectDelegate?

    
    deinit {
        stopCollect()
        self.videoOutput.setSampleBufferDelegate(nil, queue: DispatchQueue.main)
        self.removeInputAndOutput()
    }
    
    init(sessionPreset: AVCaptureSession.Preset = .vga640x480, position: AVCaptureDevice.Position = .front, delegate: WRSVideoCollectDelegate? = nil) {
        self.session =  AVCaptureSession()
        self.videoOutput = AVCaptureVideoDataOutput()
        self.videoProcessingQueue = DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.high)
        self.delegate = delegate
        
        super.init()
        
        let devices = AVCaptureDevice.devices(for: AVMediaType.video)
        for tempDevice in devices {
            if tempDevice.position == position {
                self.device = tempDevice
                break
            }
        }

        self.session.beginConfiguration()
        
        // 增加视频输入
        if let tempDevice = self.device {
            if let tempVideoInput = try? AVCaptureDeviceInput(device: tempDevice) {
                self.videoInput = tempVideoInput
                
                if self.session.canAddInput(tempVideoInput) {
                    self.session.addInput(tempVideoInput)
                }
            }
        }
        
        self.videoOutput.alwaysDiscardsLateVideoFrames = false
        
        // 设置视频输出是否是YUV格式
        var videoSettings = [String: Any]();
        var pixelBufferPixelFormat = NSNumber(value: kCVPixelFormatType_32BGRA)
        if self.collectAsYUV {
            var supportsFullYUVRange = false
            let formatTypes =  self.videoOutput.availableVideoPixelFormatTypes
            for tempFormatType in formatTypes {
                if tempFormatType == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange {
                    supportsFullYUVRange = true
                    break
                }
            }
            if supportsFullYUVRange {
                pixelBufferPixelFormat = NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
            } else {
                pixelBufferPixelFormat = NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
            }
        }
        videoSettings[kCVPixelBufferPixelFormatTypeKey as String] = pixelBufferPixelFormat
        self.videoOutput.videoSettings = videoSettings
        
        // 设置视频buffer处理线程
//        self.videoProcessingQueue = DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.high)
        self.videoOutput.setSampleBufferDelegate(self, queue: self.videoProcessingQueue)
        
        if self.session.canAddOutput(self.videoOutput) {
            self.session.addOutput(self.videoOutput)
        }
        
        if self.session.canSetSessionPreset(sessionPreset) {
            self.session.canSetSessionPreset(sessionPreset)
        }
        
        self.session.commitConfiguration()
       
    }
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if let tempDelegate = self.delegate {
            tempDelegate.collect(collect: self, sampleBuffer: sampleBuffer)
        }
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
    }
    
    
    public func startCollect() {
        if !self.session.isRunning {
            self.session.startRunning()
        }
    }
    
    public func stopCollect() {
        if self.session.isRunning {
            self.session.stopRunning()
        }
    }
    
    public func removeInputAndOutput() {
        self.session.beginConfiguration()
        if let tempInput = self.videoInput {
            self.session.removeInput(tempInput)
        }
        self.session.removeOutput(self.videoOutput)
        self.videoInput = nil
//        self.videoOutput = nil
        self.session.commitConfiguration()
    }
}
