//
//  Estimation.swift
//  DepthCalorieCam
//
//  Created by Yoshikazu Ando on 2019/01/11.
//  Copyright © 2019 Yoshikazu Ando. All rights reserved.
//

import Foundation
import EasyImagy

class Estimation {
    
    static let classNames = [
        "酢豚",
        "唐揚げ",
        "コロッケ"
    ]
    static let regressionCoefficients = [
        "酢豚": [1.50, 33.1],
        "唐揚げ": [1.91, 53.4],
        "コロッケ": [1.43, 7.30]
    ]

    static func estimate(pixelBuffer: CVPixelBuffer, depthInfo: DepthAnalyzationResult,
                         progress: ((Float, String?) -> Void)?, success: (([EstimationResult]) -> Void)?, failure: ((String) -> Void)?) {
        let depthImage = depthInfo.calibratedDepth

        // ------------------------------
        // Detection
        // ------------------------------
        progress?(1.0 / 5.0, "Running Detection")

        let detectionResults = [
            DetectionResult(normalizedRect: CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0), score: 1.0)
        ]

        // ------------------------------
        // Classification
        // ------------------------------
        (progress?(2.0 / 5.0, "Running Classification"))!

        let imageWidth = CVPixelBufferGetWidth(pixelBuffer)
        let imageHeight = CVPixelBufferGetHeight(pixelBuffer)
        let imageSize = CGSize(width: imageWidth, height: imageHeight)

        var classificationResults = [(className: String, rect: CGRect, rgbImage: CVPixelBuffer)]()
        for detectionResult in detectionResults {
            let originRect = detectionResult.normalizedRect.denormalizedRect(in: imageSize)
            guard let croppedImage = pixelBuffer.crop(rect: originRect),
                  let classificationResult = Xception.shared.predict(pixelBuffer: croppedImage) else {
                failure?("Failed to classify images.")
                return
            }

            classificationResults.append((classificationResult.className, detectionResult.normalizedRect, croppedImage))
        }

        guard !classificationResults.isEmpty else {
            failure?("Failed to classify images.")
            return
        }

        // ------------------------------
        // Segmentation
        // ------------------------------
        progress?(3.0 / 5.0, "Running Segmentation")

        let depthSize = CGSize(width: depthImage.width, height: depthImage.height)
        typealias SegmentationResult = (className: String, rect: CGRect, image: CVPixelBuffer, mask: Image<Bool>)
        var segmentationResults = [SegmentationResult]()
        for classificationResult in classificationResults {
            guard let maskImage = UNet.shared.predict(pixelBuffer: classificationResult.rgbImage) else {
                failure?("Failed to segment images.")
                return
            }

            segmentationResults.append((classificationResult.className, classificationResult.rect, classificationResult.rgbImage, maskImage))
        }

        guard !segmentationResults.isEmpty else {
            failure?("Failed to segment images.")
            return
        }

        // ------------------------------
        // Volume Estimation
        // ------------------------------
        progress?(4.0 / 5.0, "Running Calorie Estimation")

        typealias VolumeEstimationResult = (className: String, rect: CGRect, image: CVPixelBuffer, depthImage: UIImage, maskedImage: UIImage, area: Double, volume: Double)
        let volumeResults: [VolumeEstimationResult] = segmentationResults.compactMap { res in
            let rect = res.rect.denormalizedRect(in: depthSize)
            let croppedDepthImage = Image<Double>(depthImage[Int(rect.origin.x)..<Int(rect.origin.x + rect.width), Int(rect.origin.y)..<Int(rect.origin.y + rect.height)])
            let maskedImage = res.mask.resizedTo(width: croppedDepthImage.width, height: croppedDepthImage.height)
            assert(croppedDepthImage.width == maskedImage.width && croppedDepthImage.height == maskedImage.height)

            var area = 0.0, volume = 0.0
            croppedDepthImage.withUnsafeBufferPointer { (depthPtr: UnsafeBufferPointer<Double>) in
                maskedImage.withUnsafeBufferPointer { (maskPtr: UnsafeBufferPointer<Bool>) in
                    zip(depthPtr, maskPtr).filter { $1 }.forEach { (depth: Double, mask: Bool) in
                        let areaExpansionRatio = pow(depthInfo.baseDepth / depth, 2.0)
                        let areaPerPixel = depthInfo.areaPerPixel / areaExpansionRatio

                        area += areaPerPixel
                        volume += (depthInfo.baseDepth - depth) * areaPerPixel
                    }
                }
            }

            var im = Image<RGBA<UInt8>>(uiImage: UIImage(cvPixelBuffer: res.image)!).resizedTo(width: res.mask.width, height: res.mask.height)
            for y in 0..<res.mask.height {
                for x in 0..<res.mask.width {
                    if !res.mask[x, y] {
                        im[x, y] = RGBA<UInt8>.init(gray: 0, alpha: 0)
                    }
                }
            }

            return (res.className, res.rect, res.image, croppedDepthImage.uiImage, im.uiImage, area, volume)
        }

        var estimationResults = [EstimationResult]()
        for res in volumeResults {
            guard let croppedImage = UIImage(cvPixelBuffer: res.image),
                  let coefs = Estimation.regressionCoefficients[res.className] else {
                failure?("Failed to estimate calorie.")
                return
            }

            let calorie = res.volume * 1e6 * coefs[0] + coefs[1]

            estimationResults.append(EstimationResult(className: res.className,
                                                      normalizedRect: res.rect,
                                                      area: res.area,
                                                      volume: res.volume,
                                                      calorie: calorie,
                                                      rgbImage: croppedImage,
                                                      depthImage: res.depthImage,
                                                      maskedImage: res.maskedImage,
                                                      depthAnalysisResult: depthInfo))
        }

        guard !estimationResults.isEmpty else {
            failure?("Failed to estimate calorie.")
            return
        }

        success?(estimationResults)
    }

    static func estimateWithoutDepth(pixelBuffer: CVPixelBuffer,
                                     progress: ((Float, String?) -> Void)?, success: (([EstimationResult]) -> Void)?, failure: ((String) -> Void)?) {

        // ------------------------------
        // Detection
        // ------------------------------
        progress?(1.0 / 4.0, "Running Detection")

        let detectionResults = [
            DetectionResult(normalizedRect: CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0), score: 1.0)
        ]

        // ------------------------------
        // Classification
        // ------------------------------
        (progress?(2.0 / 4.0, "Running Classification"))!

        let imageWidth = CVPixelBufferGetWidth(pixelBuffer)
        let imageHeight = CVPixelBufferGetHeight(pixelBuffer)
        let imageSize = CGSize(width: imageWidth, height: imageHeight)

        var classificationResults = [(className: String, rect: CGRect, rgbImage: CVPixelBuffer)]()
        for detectionResult in detectionResults {
            let originRect = detectionResult.normalizedRect.denormalizedRect(in: imageSize)
            guard let croppedImage = pixelBuffer.crop(rect: originRect),
                  let classificationResult = Xception.shared.predict(pixelBuffer: croppedImage) else {
                failure?("Failed to classify images.")
                return
            }

            classificationResults.append((classificationResult.className, detectionResult.normalizedRect, croppedImage))
        }

        guard !classificationResults.isEmpty else {
            failure?("Failed to classify images.")
            return
        }

        // ------------------------------
        // Segmentation
        // ------------------------------
        progress?(3.0 / 4.0, "Running Segmentation")

        typealias SegmentationResult = (className: String, rect: CGRect, image: CVPixelBuffer, mask: Image<Bool>)
        var segmentationResults = [SegmentationResult]()
        for classificationResult in classificationResults {
            guard let maskImage = UNet.shared.predict(pixelBuffer: classificationResult.rgbImage) else {
                failure?("Failed to segment images.")
                return
            }

            segmentationResults.append((classificationResult.className, classificationResult.rect, classificationResult.rgbImage, maskImage))
        }

        guard !segmentationResults.isEmpty else {
            failure?("Failed to segment images.")
            return
        }

        // ------------------------------
        // Volume Estimation
        // ------------------------------
        progress?(4.0 / 4.0, "Finishing Process")

        let estimationResults: [EstimationResult] = segmentationResults.compactMap { res in
            guard let croppedImage = UIImage(cvPixelBuffer: res.image) else { return nil }

            var im = Image<RGBA<UInt8>>(uiImage: croppedImage).resizedTo(width: res.mask.width, height: res.mask.height)
            for y in 0..<res.mask.height {
                for x in 0..<res.mask.width {
                    if !res.mask[x, y] {
                        im[x, y] = RGBA<UInt8>.init(gray: 0, alpha: 0)
                    }
                }
            }

            return EstimationResult(className: res.className,
                                    normalizedRect: res.rect,
                                    area: nil,
                                    volume: nil,
                                    calorie: nil,
                                    rgbImage: croppedImage,
                                    depthImage: nil,
                                    maskedImage: im.uiImage,
                                    depthAnalysisResult: nil)
        }

        guard !estimationResults.isEmpty else {
            failure?("Failed to process.")
            return
        }

        success?(estimationResults)
    }

}
