//
//  EstimationResult.swift
//  DepthCalorieCam
//
//  Created by Yoshikazu Ando on 2019/02/05.
//  Copyright © 2019 Yoshikazu Ando. All rights reserved.
//

import Foundation

struct EstimationResult {

    enum FoodClass: String, CaseIterable {
        case subuta
        case karaage
        case croquette

        var className: String {
            return NSLocalizedString(self.rawValue, comment: "")
        }
    }

    let foodClass: FoodClass
    let normalizedRect: CGRect
    let area: Double?
    let volume: Double?
    let calorie: Double?
    let rgbImage: UIImage
    let depthImage: UIImage?
    let maskedImage: UIImage

    let depthAnalysisResult: DepthAnalyzationResult?

}
