//
//  CGRect+Extensions.swift
//  DepthCalorieCam
//
//  Created by Yoshikazu Ando on 2019/01/11.
//  Copyright © 2019 Yoshikazu Ando. All rights reserved.
//

import Foundation
import CoreGraphics

extension CGRect {
    
    var xRange: CountableRange<Int> {
        return Int(self.origin.x)..<Int(self.origin.x + self.size.width)
    }
    var yRange: CountableRange<Int> {
        return Int(self.origin.y)..<Int(self.origin.y + self.size.height)
    }

    func normalizedRect(in bounds: CGSize, clamp: Bool = false) -> CGRect {
        let x = self.origin.x / bounds.width
        let y = self.origin.y / bounds.height
        let width = self.size.width / bounds.width
        let height = self.size.height / bounds.height
        
        if !clamp {
            return CGRect(x: x, y: y, width: width, height: height)
        }
        
        let clampedX = x.clamp(), clampedY = y.clamp()
        let clampedWidth = clampedX + width <= 1.0 ? width : 1.0 - clampedX
        let clampedHeight = clampedY + height <= 1.0 ? height : 1.0 - clampedY
        
        return CGRect(x: clampedX, y: clampedY, width: clampedWidth, height: clampedHeight)
    }

    func denormalizedRect(in bounds: CGSize) -> CGRect {
        return CGRect(x: self.origin.x * bounds.width, y: self.origin.y * bounds.height,
                      width: self.size.width * bounds.width, height: self.size.height * bounds.height)
    }

}
