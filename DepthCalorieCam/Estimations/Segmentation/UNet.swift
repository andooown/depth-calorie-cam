//
//  UNet.swift
//  DepthCalorieCam
//
//  Created by Yoshikazu Ando on 2019/02/06.
//  Copyright © 2019 Yoshikazu Ando. All rights reserved.
//

import Foundation
import EasyImagy

class UNet {

    static let shared = UNet()

    private let imageSize = 560
    private var model: UNet_560_1?

    private init() { }

    func setup() {
        self.model = UNet_560_1()
    }

    func predict(pixelBuffer: CVPixelBuffer) -> Image<Bool>? {
        guard let model = self.model,
              let resizedBuffer = pixelBuffer.resize(width: self.imageSize, height: self.imageSize) else { return nil }

        guard let output = try? model.prediction(img: resizedBuffer) else { return nil }
        let features = output.output1
        
        var result = Image<Bool>(width: self.imageSize, height: self.imageSize, pixel: false)
        for y in 0..<self.imageSize {
            for x in 0..<self.imageSize {
                if (features[[0, y, x] as [NSNumber]].doubleValue > 0.5) {
                    result[x, y] = true
                }
            }
        }

        let srcWidth = CVPixelBufferGetWidth(pixelBuffer)
        let srcHeight = CVPixelBufferGetHeight(pixelBuffer)
        return result.resizedTo(width: srcWidth, height: srcHeight)
    }
    
}
