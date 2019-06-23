//
//  ClassificationResult.swift
//  DepthCalorieCam
//
//  Created by Yoshikazu Ando on 2019/01/11.
//  Copyright © 2019 Yoshikazu Ando. All rights reserved.
//

import Foundation

struct ClassificationResult {
    
    let classIndex: Int
    let className: String
    
    let score: Double
    
    init(classIndex: Int, score: Double) {
        self.classIndex = classIndex
        self.className = Estimation.classNames[classIndex]
        self.score = score
    }
    
}
