//
//  VideoCapture.swift
//  DepthCalorieCam
//
//  Created by Yoshikazu Ando on 2018/12/25.
//  Copyright © 2018 Yoshikazu Ando. All rights reserved.
//

import AVFoundation

typealias SynchronizedFrameHandler = (CVPixelBuffer, AVDepthData) -> Void
typealias VideoFrameHandler = (CVPixelBuffer) -> Void

class VideoCapture: NSObject {
    
    private let captureSession = AVCaptureSession()
    private var captureDevice: AVCaptureDevice!
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let depthDataOutput = AVCaptureDepthDataOutput()
    
    private let dataOutputQueue = DispatchQueue(label: "com.andooown.dataOutputQueue")
    private var dataOutputSynchronizer: AVCaptureDataOutputSynchronizer!

    private var cameraPreviewLayer: AVCaptureVideoPreviewLayer!

    var synchronizedFrameHandler: SynchronizedFrameHandler?
    var videoFrameHandler: VideoFrameHandler?
    private(set) var canCaptureDepth = true

    var yFieldOfView: Double {
        return 2.0 * atan(tan(0.5 * Double(self.captureDevice.activeFormat.videoFieldOfView) * Double.pi / 180.0) / Double(self.captureDevice.videoZoomFactor)) * 180.0 / Double.pi
    }

    init?(previewContainer: CALayer?) {
        super.init()
        
        self.captureSession.beginConfiguration()
        
        guard self.setupCamera() else { return nil }
        self.setupPreviewLayer(container: previewContainer)

        self.captureSession.commitConfiguration()
    }
    
    private func setupCamera() -> Bool {
        self.captureSession.sessionPreset = .photo
        
        let depthDevices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera], mediaType: .video, position: .back).devices
        if let device = depthDevices.first {
            self.captureDevice = device
            self.captureDevice.selectDepthFormat()

            self.setupVideoCamera(device: device)
            self.setupDepthCamera(device: device)
        } else {
            let videoDevices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices
            guard let device = videoDevices.first else { return false }
            self.captureDevice = device
            self.canCaptureDepth = false

            self.setupVideoCamera(device: device)
        }

        return true
    }

    private func setupVideoCamera(device: AVCaptureDevice) {
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: device),
              self.captureSession.canAddInput(videoDeviceInput) else { fatalError() }
        self.captureSession.addInput(videoDeviceInput)

        self.videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
        self.videoDataOutput.setSampleBufferDelegate(self, queue: self.dataOutputQueue)
        guard self.captureSession.canAddOutput(self.videoDataOutput) else { fatalError() }
        self.captureSession.addOutput(self.videoDataOutput)
        self.videoDataOutput.connection(with: .video)?.videoOrientation = .portrait
    }

    private func setupDepthCamera(device: AVCaptureDevice) {
        self.depthDataOutput.isFilteringEnabled = true
        self.depthDataOutput.setDelegate(self, callbackQueue: self.dataOutputQueue)
        guard self.captureSession.canAddOutput(self.depthDataOutput) else { fatalError() }
        self.captureSession.addOutput(self.depthDataOutput)
        self.depthDataOutput.connection(with: .depthData)?.videoOrientation = .portrait

        self.dataOutputSynchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [self.videoDataOutput, self.depthDataOutput])
        self.dataOutputSynchronizer.setDelegate(self, queue: self.dataOutputQueue)
    }
    
    private func setupPreviewLayer(container: CALayer?) {
        self.cameraPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
        self.cameraPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
        self.cameraPreviewLayer.connection?.videoOrientation = .portrait

        guard let container = container else { return }
        self.cameraPreviewLayer.frame = container.bounds
        container.insertSublayer(self.cameraPreviewLayer, at: 0)
    }

    func startCapture() {
        guard !self.captureSession.isRunning else { return }
        self.captureSession.startRunning()
    }

    func stopCapture() {
        guard self.captureSession.isRunning else { return }
        self.captureSession.stopRunning()
    }

}

extension VideoCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        self.videoFrameHandler?(pixelBuffer)
    }

}

extension VideoCapture: AVCaptureDepthDataOutputDelegate {
    
    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {
        // Not called
        print("depthDataOutput(_:didOutput:timestamp:connection)")
    }
    
}

extension VideoCapture: AVCaptureDataOutputSynchronizerDelegate {
    
    func dataOutputSynchronizer(_ synchronizer: AVCaptureDataOutputSynchronizer, didOutput synchronizedDataCollection: AVCaptureSynchronizedDataCollection) {
        guard let syncedVideoData = synchronizedDataCollection.synchronizedData(for: self.videoDataOutput) as? AVCaptureSynchronizedSampleBufferData,
            !syncedVideoData.sampleBufferWasDropped,
            let imagePixelBuffer = CMSampleBufferGetImageBuffer(syncedVideoData.sampleBuffer) else { return }
        
        guard let syncedDepthData = synchronizedDataCollection.synchronizedData(for: self.depthDataOutput) as? AVCaptureSynchronizedDepthData,
            !syncedDepthData.depthDataWasDropped else { return }
        
        self.synchronizedFrameHandler?(imagePixelBuffer, syncedDepthData.depthData)
    }
    
}
