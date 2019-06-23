//
//  CameraViewController.swift
//  DepthCalorieCam
//
//  Created by Yoshikazu Ando on 2018/12/25.
//  Copyright © 2018 Yoshikazu Ando. All rights reserved.
//

import UIKit
import AVFoundation
import EasyImagy

struct DepthAnalyzationResult {

    let calibratedDepth: Image<Double>
    let baseDepth: Double

    let width: Double
    let height: Double

    var areaPerPixel: Double {
        return (self.width * self.height) / Double(self.calibratedDepth.width * self.calibratedDepth.height)
    }

    init(depth: Image<Double>, baseDepth: Double, width: Double, height: Double) {
        self.calibratedDepth = depth
        self.baseDepth = baseDepth
        self.width = width
        self.height = height
    }

}


class CameraViewController: UIViewController {

    // MARK: - Const

    private static let kDepthCalibrationSlope = 1.063
    private static let kDepthCalibrationIntercept = 3.243 * 1e-3
    private static let kDepthIgnorePercentage = 0.2                 // 深度の上位何 % を無視するか

    // MARK: - Property
    
    @IBOutlet weak var cameraView: UIImageView!
    @IBOutlet weak var subCameraView: UIImageView!
    @IBOutlet weak var captureButton: CaptureButton!

    private var videoCapture: VideoCapture!
    private var isCapturing = false
    private var isShowingDepth = false

    private let workerQueue = DispatchQueue(label: "com.andooown.workerQueue", attributes: .concurrent)
    private var currentFrame: (pixelBuffer: CVPixelBuffer, depthData: AVDepthData?)?

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    // MARK: - Override function

    override func viewDidLoad() {
        super.viewDidLoad()

        UNet.shared.setup()
        Xception.shared.setup()

        guard let videoCapture = VideoCapture(previewContainer: nil) else {
            self.showDialog(message: "この端末は動作対象外です。")
            return
        }

        self.videoCapture = videoCapture
        if videoCapture.canCaptureDepth {
            self.videoCapture.synchronizedFrameHandler = { [weak self] pixelBuffer, depthData in
                guard let self = self, !self.isCapturing else {
                    return
                }

                if let mainImage = UIImage(cvPixelBuffer: self.isShowingDepth ? depthData.depthDataMap : pixelBuffer),
                   let subImage = UIImage(cvPixelBuffer: self.isShowingDepth ? pixelBuffer : depthData.depthDataMap) {
                    DispatchQueue.main.async {
                        self.cameraView.image = mainImage
                        self.subCameraView.image = subImage
                    }
                }

                self.currentFrame = (pixelBuffer, depthData)
            }
        } else {
            self.videoCapture.videoFrameHandler = { [weak self] pixelBuffer in
                guard let self = self, !self.isCapturing else {
                    return
                }

                if let image = UIImage(cvPixelBuffer: pixelBuffer) {
                    DispatchQueue.main.async {
                        self.cameraView.image = image
                    }
                }

                self.currentFrame = (pixelBuffer, nil)
            }

            self.showDialog(message: "カロリー量の推定は深度が取得できるデュアルカメラを搭載した端末のみで利用可能です。")
        }

        self.videoCapture.startCapture()

        self.setupViews()
    }

    // MARK: -
    
    private func setupViews() {
        if self.videoCapture.canCaptureDepth {
            let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.subCameraViewTapped(_:)))
            self.subCameraView.addGestureRecognizer(gestureRecognizer)
        } else {
            self.subCameraView.isHidden = true
        }

        SVProgressHUD.setDefaultMaskType(.black)
    }

    @objc private func subCameraViewTapped(_ sender: UITapGestureRecognizer) {
        self.isShowingDepth = !self.isShowingDepth
    }

    // MARK: - Depth

    private func analyzeDepth(depthDataMap: CVPixelBuffer) -> DepthAnalyzationResult {
        let width = CVPixelBufferGetWidth(depthDataMap)
        let height = CVPixelBufferGetHeight(depthDataMap)
        var depthImage = Image<Double>(width: width, height: height, pixels: depthDataMap.rawPixelData)

        // Calibration
        let depthLimit: Double = depthImage.sorted(by: {$0 > $1})[Int(Double(depthImage.count) * CameraViewController.kDepthIgnorePercentage)]
        let calibratedDepthLimit: Double = CameraViewController.kDepthCalibrationSlope * depthLimit + CameraViewController.kDepthCalibrationIntercept
        depthImage.withUnsafeMutableBufferPointer { (ptr: inout UnsafeMutableBufferPointer<Double>) in
            for index in 0..<ptr.count {
                let calibratedDepth: Double = CameraViewController.kDepthCalibrationSlope * ptr[index] + CameraViewController.kDepthCalibrationIntercept
                ptr[index] = min(calibratedDepth, calibratedDepthLimit)
            }
        }

        let yFov = self.videoCapture.yFieldOfView
        let xFov = Double(depthImage.width) / Double(depthImage.height) * yFov

        let yRad = yFov * Double.pi / 180.0
        let xRad = xFov * Double.pi / 180.0

        let top    = depthImage[depthImage.width / 2, 0]
        let bottom = depthImage[depthImage.width / 2, depthImage.height - 1]
        let left   = depthImage[0,                    depthImage.height / 2]
        let right  = depthImage[depthImage.width - 1, depthImage.height / 2]

        let base: Double = (top * cos(yRad / 2.0) + bottom * cos(yRad / 2.0) + left * cos(xRad / 2.0) + right * cos(xRad / 2.0)) / 4.0 * 1.052631579

        let baseHeight = 2.0 * base * tan(yRad / 2.0)
        let baseWidth = 2.0 * base * tan(xRad / 2.0)

        return DepthAnalyzationResult(depth: depthImage, baseDepth: base, width: baseWidth, height: baseHeight)
    }

    // MARK: - Estimation

    private func estimate() {
        self.isCapturing = true

        guard let currentFrame = self.currentFrame,
              let depthData = currentFrame.depthData else {
            self.isCapturing = false
            return
        }
        let pixelBuffer = currentFrame.pixelBuffer

        self.workerQueue.async { [weak self] in
            guard let self = self else { return }

            let depthInfo = self.analyzeDepth(depthDataMap: depthData.depthDataMap)

            Estimation.estimate(
                pixelBuffer: pixelBuffer, depthInfo: depthInfo,
                progress: { progress, status in
                    SVProgressHUD.showProgress(progress, status: status)
                },
                success: { estimationResults in
                    SVProgressHUD.showSuccess(withStatus: "Complete")

                    DispatchQueue.main.async {
                        guard let resultViewController = UIStoryboard(name: "ResultDetailViewController", bundle: nil).instantiateInitialViewController() as? ResultDetailViewController else { return }

                        resultViewController.estimationResult = estimationResults[0]

                        self.present(resultViewController, animated: true) {
                            SVProgressHUD.dismiss()
                            self.isCapturing = false
                        }
                    }
                },
                failure: { [weak self] message in
                    DispatchQueue.main.async {
                        guard let self = self else { return }

                        SVProgressHUD.dismiss() {
                            let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)

                            let defaultAction = UIAlertAction(title: "OK", style: .default) { _ in
                                alertController.dismiss(animated: true)
                                self.isCapturing = false
                            }
                            alertController.addAction(defaultAction)

                            self.present(alertController, animated: true)
                        }
                    }
                })
        }
    }

    private func estimateWithoutDepth() {
        self.isCapturing = true

        guard let pixelBuffer = self.currentFrame?.pixelBuffer else {
            self.isCapturing = false
            return
        }

        self.workerQueue.async { [weak self] in
            guard let self = self else { return }

            Estimation.estimateWithoutDepth(
                pixelBuffer: pixelBuffer,
                progress: { progress, status in
                    SVProgressHUD.showProgress(progress, status: status)
                },
                success: { estimationResults in
                    SVProgressHUD.showSuccess(withStatus: "Complete")

                    DispatchQueue.main.async {
                        guard let resultViewController = UIStoryboard(name: "ResultDetailViewController", bundle: nil).instantiateInitialViewController() as? ResultDetailViewController else { return }

                        resultViewController.estimationResult = estimationResults[0]

                        self.present(resultViewController, animated: true) {
                            SVProgressHUD.dismiss()
                            self.isCapturing = false
                        }
                    }
                },
                failure: { [weak self] message in
                    DispatchQueue.main.async {
                        guard let self = self else { return }

                        SVProgressHUD.dismiss() {
                            let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)

                            let defaultAction = UIAlertAction(title: "OK", style: .default) { _ in
                                alertController.dismiss(animated: true)
                                self.isCapturing = false
                            }
                            alertController.addAction(defaultAction)

                            self.present(alertController, animated: true)
                        }
                    }
                })
        }
    }

    // MARK: - Outlet function
    
    @IBAction func captureButtonTapped(_ sender: Any) {
        guard !self.isCapturing else { return }

        if self.videoCapture.canCaptureDepth {
            self.estimate()
        } else {
            self.estimateWithoutDepth()
        }
    }

    // MARK: - Utils

    private var nowDateString: String {
        let date = Date()

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"

        return formatter.string(from: date)
    }
    
    private func getFileUrl(with fileName: String) -> URL? {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(fileName)
    }

    private func save(uiImage: UIImage, fileName: String) {
        guard let fileUrl = getFileUrl(with: fileName),
              let data = uiImage.pngData() else { return }
        
        do {
            try data.write(to: fileUrl, options: .atomic)
        } catch {
            print(error)
        }
    }

    private func save(depth: CVPixelBuffer, fileName: String) {
        guard let fileUrl = getFileUrl(with: fileName) else { return }

        let width = CVPixelBufferGetWidth(depth)
        let height = CVPixelBufferGetHeight(depth)
        let rawPixels = depth.rawPixelData

        let str = "\(width),\(height)\n\(rawPixels.map { String(format: "%.5f", $0) }.joined(separator: ","))"
        do {
            try str.write(to: fileUrl, atomically: true, encoding: .utf8)
        } catch {
            print(error)
        }
    }

    private func showDialog(message: String) {
        DispatchQueue.main.async { [weak self] in
            let alertController = UIAlertController(
                    title: nil,
                    message: message,
                    preferredStyle: .alert)

            let defaultAction = UIAlertAction(title: "OK", style: .default) { _ in
                alertController.dismiss(animated: true)
            }
            alertController.addAction(defaultAction)

            self?.present(alertController, animated: true)
        }
    }

}
