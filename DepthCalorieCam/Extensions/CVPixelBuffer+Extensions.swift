//
//  CVPixelBuffer+Extensions.swift
//  DepthFovTest
//
//  Created by Yoshikazu Ando on 2018/12/22.
//  Copyright © 2018 Yoshikazu Ando. All rights reserved.
//

import Foundation
import AVFoundation
import CoreImage

extension CVPixelBuffer {

    var rawPixelData: [Double] {
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)

        CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))
        defer { CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0)) }

        let baseAddress = CVPixelBufferGetBaseAddress(self)
        let buffer = UnsafeBufferPointer<Float>(start: baseAddress?.assumingMemoryBound(to: Float.self), count: width * height)

        let pixels = [Float](buffer).map { Double($0) }

        return pixels
    }
    
    var cgImage: CGImage? {
        let ciImage = CIImage(cvPixelBuffer: self)
        
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        let ciContext = CIContext()
        
        return ciContext.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: width, height: height))
    }

    func resize(width: Int, height: Int) -> CVPixelBuffer? {
        let ciImage = CIImage(cvPixelBuffer: self)
        let scaleX = CGFloat(width) / CGFloat(CVPixelBufferGetWidth(self)), scaleY = CGFloat(height) / CGFloat(CVPixelBufferGetHeight(self))
        let transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
        let resizedCIImage = ciImage.transformed(by: transform)

        let context = CIContext()
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(nil, width, height, CVPixelBufferGetPixelFormatType(self), nil, &buffer)
        guard status == kCVReturnSuccess, let resizedBuffer = buffer else { return nil }
        context.render(resizedCIImage, to: resizedBuffer)

        return resizedBuffer
    }

    func crop(rect: CGRect) -> CVPixelBuffer? {
        let ciImage = CIImage(cvPixelBuffer: self)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(self), height: CVPixelBufferGetHeight(self))) else { return nil }

        guard let croppedCGImage = cgImage.cropping(to: rect) else { return nil }

        var buffer: CVPixelBuffer?
        let attributes = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ]
        let status = CVPixelBufferCreate(nil, Int(rect.size.width), Int(rect.size.height), kCVPixelFormatType_32ARGB, attributes as CFDictionary, &buffer)
        guard status == kCVReturnSuccess, let pixelBuffer = buffer else { return nil }

        guard CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0)) == kCVReturnSuccess else { return nil }
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0)) }
        guard let cgContext = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer),
                                        width: Int(rect.size.width), height: Int(rect.size.height),
                                        bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else { return nil }
        cgContext.draw(croppedCGImage, in: CGRect(x: 0, y: 0, width: rect.size.width, height: rect.size.height))

        return pixelBuffer
    }

}
