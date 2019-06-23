//
//  CGFloat+Extensions.swift
//  DepthCalorieCam
//
//  Created by Yoshikazu Ando on 2019/01/11.
//  Copyright © 2019 Yoshikazu Ando. All rights reserved.
//

import Foundation
import CoreGraphics

extension CGFloat {

    func clamp(minValue: CGFloat = 0, maxValue: CGFloat = 1) -> CGFloat {
        return Swift.max(minValue, Swift.min(self, maxValue))
    }

}
