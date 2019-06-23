//
//  Xception.swift
//  DepthCalorieCam
//
//  Created by Yoshikazu Ando on 2019/02/14.
//  Copyright © 2019 Yoshikazu Ando. All rights reserved.
//

import Foundation
import CoreML
import CoreGraphics

class Xception {

    static let shared = Xception()

    private let imageSize = 299
    private var model: Xception_299_1?

    private init() {
    }

    func setup() {
        self.model = Xception_299_1()
    }

    func predict(pixelBuffer: CVPixelBuffer) -> ClassificationResult? {
        guard let model = self.model,
              let resizedBuffer = pixelBuffer.resize(width: self.imageSize, height: self.imageSize) else { return nil }

        guard let output = try? model.prediction(image: resizedBuffer) else { return nil }
        let result = output.output1.doubleArray.argmax()

        return ClassificationResult(classIndex: result.index, score: result.value)
    }

}
