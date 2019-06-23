//
//  PointCloud.swift
//  DepthCalorieCam
//
//  Created by Yoshikazu Ando on 2019/03/04.
//  Copyright © 2019 Yoshikazu Ando. All rights reserved.
//
//  Reference: https://github.com/shu223/iOS-Depth-Sampler/blob/master/iOS-Depth-Sampler/Samples/PointCloud/PointCloud.swift

import Foundation

import SceneKit

struct PointCloudVertex {

    var x: Float, y: Float, z: Float
    var r: Float, g: Float, b: Float

    static var zero: PointCloudVertex {
        return PointCloudVertex(x: 0, y: 0, z: 0, r: 0, g: 0, b: 0)
    }

}

class PointCloud: NSObject {
    
    static func buildNode(points: [PointCloudVertex]) -> SCNNode {
        let vertexData = NSData(
            bytes: points,
            length: MemoryLayout<PointCloudVertex>.size * points.count
        )
        let positionSource = SCNGeometrySource(
            data: vertexData as Data,
            semantic: SCNGeometrySource.Semantic.vertex,
            vectorCount: points.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<PointCloudVertex>.size
        )
        let colorSource = SCNGeometrySource(
            data: vertexData as Data,
            semantic: SCNGeometrySource.Semantic.color,
            vectorCount: points.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: MemoryLayout<Float>.size * 3,
            dataStride: MemoryLayout<PointCloudVertex>.size
        )
        let element = SCNGeometryElement(
            data: nil,
            primitiveType: .point,
            primitiveCount: points.count,
            bytesPerIndex: MemoryLayout<Int>.size
        )

        // for bigger dots
        element.pointSize = 10
        element.minimumPointScreenSpaceRadius = 1
        element.maximumPointScreenSpaceRadius = 5
        
        let pointsGeometry = SCNGeometry(sources: [positionSource, colorSource], elements: [element])

        return SCNNode(geometry: pointsGeometry)
    }
    
}
