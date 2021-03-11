//
//  VideoCollect.swift
//  WRSLiveStreaming
//
//  Created by jack on 2021/3/10.
//

import Foundation
import GPUImage

public protocol WRSVideoCaptureDelegate: NSObjectProtocol {
    func capture(capture: WRSVideoCapture, pixelBuffer: Unmanaged<CVPixelBuffer>);
}

public class WRSVideoCapture: NSObject {
    var videoCamera: GPUImageVideoCamera
    var beautifyFilter: GPUImageBeautyFilter
    var gpuImageView: GPUImageView
    weak var deletate: WRSVideoCaptureDelegate?

    var preView: UIView? {
        set {
            if let _ = self.gpuImageView.superview {
                self.gpuImageView.removeFromSuperview()
            }
            let superView = newValue
            superView?.addSubview(self.gpuImageView)
            self.gpuImageView.translatesAutoresizingMaskIntoConstraints = false
            let view = self.gpuImageView;
            let top = NSLayoutConstraint(item: view, attribute: NSLayoutConstraint.Attribute.top, relatedBy: NSLayoutConstraint.Relation.equal, toItem: superView, attribute: NSLayoutConstraint.Attribute.top, multiplier: CGFloat(1.0), constant: CGFloat(0))
            let bottom = NSLayoutConstraint(item: view, attribute: NSLayoutConstraint.Attribute.bottom, relatedBy: NSLayoutConstraint.Relation.equal, toItem: superView, attribute: NSLayoutConstraint.Attribute.bottom, multiplier: CGFloat(1.0), constant: CGFloat(0))
            let left: NSLayoutConstraint = NSLayoutConstraint(item: view, attribute: NSLayoutConstraint.Attribute.left, relatedBy: NSLayoutConstraint.Relation.equal, toItem: superView, attribute: NSLayoutConstraint.Attribute.left, multiplier: CGFloat(1.0), constant: CGFloat(0))
            let right: NSLayoutConstraint = NSLayoutConstraint(item: view, attribute: NSLayoutConstraint.Attribute.right, relatedBy: NSLayoutConstraint.Relation.equal, toItem: superView, attribute: NSLayoutConstraint.Attribute.right, multiplier: CGFloat(1.0), constant: CGFloat(0))
            superView?.addConstraints([top, bottom, left, right])
        }
        get {
            return self.gpuImageView.superview
        }
        
    }
    
    
    
    init(sessionPreset: AVCaptureSession.Preset, position: AVCaptureDevice.Position) {
        self.videoCamera = GPUImageVideoCamera(sessionPreset: sessionPreset.rawValue, cameraPosition: position)
        self.beautifyFilter = GPUImageBeautyFilter()
        self.gpuImageView = GPUImageView()
        self.gpuImageView.fillMode = .preserveAspectRatioAndFill
        super.init()
        self.videoCamera.horizontallyMirrorRearFacingCamera = false
        self.videoCamera.horizontallyMirrorFrontFacingCamera = true
        self.videoCamera.outputImageOrientation = .portrait;
        self.videoCamera.addTarget(self.beautifyFilter)
        self.beautifyFilter.frameProcessingCompletionBlock = {
            [weak self] (gpuImageOutput: GPUImageOutput?, time: CMTime)  in
            guard let self = self else { return }
            self.proceFrame(gpuImageOutput: gpuImageOutput, time: time)
        }
       
        self.beautifyFilter.addTarget(self.gpuImageView)
     
    }
    
    private func proceFrame(gpuImageOutput: GPUImageOutput?, time: CMTime) {
        if let tempDelegate = self.deletate, let imageFrameBuffer = gpuImageOutput?.framebufferForOutput() {
            let pixelBuffer: Unmanaged<CVPixelBuffer> = imageFrameBuffer.pixelBuffer()
            tempDelegate.capture(capture: self, pixelBuffer: pixelBuffer)
//            imageFrameBuffer.pixel
        }
    }
    
    func start() -> Void {
        self.videoCamera.startCapture()
    }
}

