//
//  WRSAVSession.swift
//  WRSLiveStreaming
//
//  Created by jack on 2021/3/11.
//

import Foundation
public class WRSAVSession: NSObject, WRSVideoCaptureDelegate, WRSHardVideoEncoderDelegate {
    var videoCapture: WRSVideoCapture
    var videoEncoder: WRSHardVideoEncoder
    var bitRate = 800*1024
    var preView: UIView? {
        set {
            self.videoCapture.preView = newValue
        }
        get {
            return self.videoCapture.preView
        }
    }
    
    init(sessionPreset: AVCaptureSession.Preset = .vga640x480, position: AVCaptureDevice.Position = .front, videoSize: CGSize) {
        self.videoCapture = WRSVideoCapture(sessionPreset: sessionPreset, position: .front)
        self.videoEncoder = WRSHardVideoEncoder(width: Int32(videoSize.width), height: Int32(videoSize.height))
        super.init()
        self.videoEncoder.delegate = self
    }
    
    // MARK: - WRSVideoCaptureDelegate
    public func videoCapture(capture: WRSVideoCapture, pixelBuffer: Unmanaged<CVPixelBuffer>) {
       let pixelBuffer: CVPixelBuffer = pixelBuffer.takeRetainedValue()
        let timeStamp: CFTimeInterval = CACurrentMediaTime() * 1000
        self.videoEncoder.encodeVideoData(pixelBuffer: pixelBuffer, timeStamp: timeStamp)
    }
    
    // MARK: - WRSHardVideoEncoderDelegate
    public func videoEncoder(encoder: WRSHardVideoEncoder, didGetSps: Data, pps: Data, timeStamp: UInt64) {
        
    }
    
    public func videoEncoder(encoder: WRSHardVideoEncoder, didEncoderFrame: Data, timeStamp: UInt64, isKeyFrame: Bool) {
        
    }
    
    public func startCapture() {
        self.videoCapture.start()
    }
}
