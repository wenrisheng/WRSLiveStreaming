//
//  WRSAVSession.swift
//  WRSLiveStreaming
//
//  Created by jack on 2021/3/11.
//

import Foundation
public class WRSAVSession: NSObject, WRSVideoCaptureDelegate {
    var videoCapture: WRSVideoCapture
    var preView: UIView? {
        set {
            self.videoCapture.preView = newValue
        }
        get {
            return self.videoCapture.preView
        }
    }
    
    init(sessionPreset: AVCaptureSession.Preset = .vga640x480, position: AVCaptureDevice.Position = .front) {
        self.videoCapture = WRSVideoCapture(sessionPreset: sessionPreset, position: .front)
        super.init()
        self.videoCapture.deletate = self
    }
    
    // MARK: - WRSVideoCaptureDelegate
    public func capture(capture: WRSVideoCapture, pixelBuffer: Unmanaged<CVPixelBuffer>) {
        
    }
    
    public func startCapture() {
        self.videoCapture.start()
    }
}
