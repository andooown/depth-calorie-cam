//
//  MLMultiArray+Extensions.swift
//  DepthCalorieCam
//
//  Created by Yoshikazu Ando on 2019/01/11.
//  Copyright © 2019 Yoshikazu Ando. All rights reserved.
//

import Foundation
import CoreML

extension MLMultiArray {
    
    var doubleArray: [Double] {
        let pointer = self.dataPointer.bindMemory(to: Double.self, capacity: self.count)
        let buffer = UnsafeBufferPointer<Double>(start: pointer, count: self.count)
        
        return [Double](buffer)
    }
    
}
