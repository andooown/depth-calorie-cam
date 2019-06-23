//
//  UIImage+Extensions.swift
//  DepthCalorieCam
//
//  Created by Yoshikazu Ando on 2019/01/01.
//  Copyright © 2019 Yoshikazu Ando. All rights reserved.
//

import Foundation
import UIKit

extension UIImage {

    convenience init?(cvPixelBuffer: CVPixelBuffer) {
        let ciImage = CIImage(cvPixelBuffer: cvPixelBuffer)

        let width = CVPixelBufferGetWidth(cvPixelBuffer)
        let height = CVPixelBufferGetHeight(cvPixelBuffer)
        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: width, height: height)) else { return nil }

        self.init(cgImage: cgImage)
    }

}
