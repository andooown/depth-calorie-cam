//
//  ResultDetailViewController.swift
//  DepthCalorieCam
//
//  Created by Yoshikazu Ando on 2019/02/06.
//  Copyright © 2019 Yoshikazu Ando. All rights reserved.
//

import UIKit
import SceneKit
import EasyImagy

class ResultDetailViewController: UIViewController {
    
    @IBOutlet weak var contentView: UIView! {
        didSet {
            self.contentView.layer.cornerRadius = 10
        }
    }
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var scnView: SCNView!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var classLabel: UILabel!
    @IBOutlet weak var calorieLabel: UILabel!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var closeButton: UIButton! {
        didSet {
            closeButton.setTitle(R.string.localizable.close_button_text(), for: .normal)
        }
    }
    
    @IBOutlet weak var classLabelHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var calorieLabelHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var infoLabelHeightConstraint: NSLayoutConstraint!
    
    var estimationResult: EstimationResult?

    private let scene = SCNScene()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupResult()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)

        guard let tapLocation = touches.first?.location(in: self.view) else { return }
        if !self.contentView.frame.contains(tapLocation) {
            self.dismiss(animated: true)
        }
    }
    
    private func setupResult() {
        guard let result = self.estimationResult else { return }
        
        self.imageView.image = result.rgbImage
        self.classLabel.text = result.foodClass.className
        
        if let calorie = result.calorie {
            self.calorieLabel.text = String(format: "%.1f kcal", calorie)
        } else {
            self.calorieLabel.isHidden = true
        }

        if let area = result.area, let volume = result.volume {
            self.infoLabel.text = String(format: "S = %.1f cm\u{00B2}, V = %.1f cm\u{00B3}", area * 1e4, volume * 1e6)
        } else {
            self.infoLabel.isHidden = true
        }

        if result.depthImage == nil {
            self.segmentedControl.removeAllSegments()
            for str in ["RGB", "Segmented"] {
                self.segmentedControl.insertSegment(withTitle: str, at: self.segmentedControl.numberOfSegments, animated: false)
            }
            self.segmentedControl.selectedSegmentIndex = 0

            let newHeight = self.classLabelHeightConstraint.constant + self.calorieLabelHeightConstraint.constant + self.infoLabelHeightConstraint.constant
            self.classLabelHeightConstraint.constant = newHeight
            self.calorieLabelHeightConstraint.constant = 0
            self.infoLabelHeightConstraint.constant = 0
        } else {
            self.setupScene()
            self.draw3DResult()
        }
    }
    
    @IBAction func segmentedValueChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            self.imageView.isHidden = false
            self.scnView.isHidden = true

            self.imageView.image = self.estimationResult?.rgbImage
        case 1:
            self.imageView.isHidden = false
            self.scnView.isHidden = true

            if let depthImage = self.estimationResult?.depthImage {
                self.imageView.image = depthImage
            } else {
                self.imageView.image = self.estimationResult?.maskedImage
            }
        case 2:
            self.imageView.isHidden = false
            self.scnView.isHidden = true

            self.imageView.image = self.estimationResult?.maskedImage
        case 3:
            self.scnView.isHidden = false
            self.imageView.isHidden = true
        default:
            break
        }
    }
    
    @IBAction func closeButtonTapped(_ sender: UIButton) {
        self.dismiss(animated: true)
    }
    
}

extension ResultDetailViewController {

    private static let kZCamera: Float = 0.5

    private func setupScene() {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 0.0
        cameraNode.camera?.zFar = 10.0
        self.scene.rootNode.addChildNode(cameraNode)
        
        cameraNode.position = SCNVector3(x: 0.0,
                                         y: 0.0,
                                         z: ResultDetailViewController.kZCamera)
        
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = .ambient
        ambientLightNode.light!.color = UIColor.white
        self.scene.rootNode.addChildNode(ambientLightNode)

        self.scnView.scene = scene
        self.scnView.showsStatistics = true
    }

    private func draw3DResult() {
        guard let result = self.estimationResult,
              let depthInfo = result.depthAnalysisResult else { return }

        let depthImage = depthInfo.calibratedDepth
        let rgbImage = Image<RGBA<UInt8>>(uiImage: result.rgbImage).resizedTo(width: depthImage.width, height: depthImage.height)
        let maskedImage = Image<RGBA<UInt8>>(uiImage: result.maskedImage).resizedTo(width: depthImage.width, height: depthImage.height)

        // Point cloud
        let baseDepth = Float(depthInfo.baseDepth)

        var vertices = [PointCloudVertex]()
        rgbImage.withUnsafeBufferPointer { rgbPtr in
            depthImage.withUnsafeBufferPointer { depthPtr in
                maskedImage.withUnsafeBufferPointer { maskPtr in
                    for (index, _) in maskPtr.enumerated().filter({ $0.1.alpha > 127 }) {
                        let rgb = rgbPtr[index]
                        let depth = depthPtr[index]

                        let row = Float(index / depthImage.width), col = Float(index % depthImage.width)
                        let x = (col / Float(depthImage.width) - 0.5) * Float(depthInfo.width)
                        let y = -(row / Float(depthImage.height) - 0.5) * Float(depthInfo.height)
                        let z = baseDepth - Float(depth)

                        let r = Float(rgb.red) / 255.0
                        let g = Float(rgb.green) / 255.0
                        let b = Float(rgb.blue) / 255.0

                        vertices.append(PointCloudVertex(x: x, y: y, z: z, r: r, g: g, b: b))
                    }
                }
            }
        }

        let pointCloudNode = PointCloud.buildNode(points: vertices)
        pointCloudNode.position = SCNVector3(x: 0, y: 0, z: 0)
        self.scene.rootNode.addChildNode(pointCloudNode)

        // Base plane
        self.createBasePlane(width: CGFloat(depthInfo.width), height: CGFloat(depthInfo.height))
    }

    private func createBasePlane(width: CGFloat, height: CGFloat) {
        let plane = SCNPlane(width: width, height: height)
        plane.widthSegmentCount = 4
        plane.heightSegmentCount = 4
        plane.firstMaterial?.transparency = 0.8
        plane.firstMaterial?.diffuse.contents = UIColor.blue
        plane.firstMaterial?.isDoubleSided = true

        let planeNode = SCNNode(geometry: plane)
        self.scene.rootNode.addChildNode(planeNode)

        planeNode.position = SCNVector3(0.0, 0.0, 0.0)
    }

}
