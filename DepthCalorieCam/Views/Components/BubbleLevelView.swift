//
//  BubbleLevelView.swift
//  DepthCalorieCam
//
//  Created by Yoshikazu Ando on 2019/03/03.
//  Copyright © 2019 Yoshikazu Ando. All rights reserved.
//

import UIKit
import AVFoundation
import CoreMotion

@IBDesignable class BubbleLevelView: UIView {

    private static let kMotionUpdateFrequency: Double = 30
    private static let kMotionScale: CGFloat = 2.0

    @IBInspectable var bubbleSizeRatio: CGFloat = 0.2
    @IBInspectable var guideCircleSizeRatio: CGFloat = 0.3
    @IBInspectable var guideWidth: CGFloat = 3.0
    @IBInspectable var errorWidth: CGFloat = 3.0

    @IBInspectable var bubbleColor: UIColor = .white
    @IBInspectable var guideColor: UIColor = .black
    @IBInspectable var errorColor: UIColor = .red
    @IBInspectable var backgroundCircleColor: UIColor = .darkGray

    private let motionManager = CMMotionManager()
    private var bubbleCenter: CGPoint = CGPoint.zero {
        didSet {
            self.setNeedsDisplay()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupView()
        self.setupMotionManager()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setupView()
        self.setupMotionManager()
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        self.setupView()
    }

    private func setupView() {
        self.backgroundColor = .clear
    }

    private func setupMotionManager() {
        guard self.motionManager.isDeviceMotionAvailable,
              let currentQueue = OperationQueue.current else { return }

        self.motionManager.deviceMotionUpdateInterval = 1.0 / BubbleLevelView.kMotionUpdateFrequency
        self.motionManager.startDeviceMotionUpdates(to: currentQueue) { motion, _ in
            guard let motion = motion else { return }

            let gravityLength = sqrt(pow(motion.gravity.x, 2.0) + pow(motion.gravity.y, 2.0) + pow(motion.gravity.z, 2.0))
            let normalizedCenter = CGPoint(x: -motion.gravity.x / gravityLength, y: motion.gravity.y / gravityLength)

            var bubbleX = normalizedCenter.x * BubbleLevelView.kMotionScale
            var bubbleY = normalizedCenter.y * BubbleLevelView.kMotionScale
            let length = sqrt(pow(bubbleX, 2.0) + pow(bubbleY, 2.0))
            if  length > 1.0 {
                bubbleX = bubbleX / length
                bubbleY = bubbleY / length
            }

            self.bubbleCenter = CGPoint(x: bubbleX * (1.0 - self.bubbleSizeRatio),
                                        y: bubbleY * (1.0 - self.bubbleSizeRatio))
        }
    }

    override func draw(_ rect: CGRect) {
        let drawRect = AVMakeRect(aspectRatio: CGSize(width: 1, height: 1), insideRect: rect)

        let backgroundCircleRect = drawRect.insetBy(dx: self.errorWidth / 2.0, dy: self.errorWidth / 2.0)
        let backgroundCirclePath = UIBezierPath(ovalIn: backgroundCircleRect)

        self.backgroundCircleColor.setFill()
        backgroundCirclePath.fill()

        let backgroundCircleRadius = backgroundCircleRect.width / 2.0
        let bubbleRadius = backgroundCircleRadius * self.bubbleSizeRatio
        let bubbleRect = CGRect(x: (1.0 + self.bubbleCenter.x) * backgroundCircleRadius - bubbleRadius,
                                y: (1.0 + self.bubbleCenter.y) * backgroundCircleRadius - bubbleRadius,
                                width: bubbleRadius * 2.0,
                                height: bubbleRadius * 2.0).offsetBy(dx: backgroundCircleRect.origin.x, dy: backgroundCircleRect.origin.y)
        let bubblePath = UIBezierPath(ovalIn: bubbleRect)

        self.bubbleColor.setFill()
        bubblePath.fill()

        let guideCircleInset = backgroundCircleRadius * (1.0 - self.guideCircleSizeRatio)
        let guideCircleRect = backgroundCircleRect.insetBy(dx: guideCircleInset, dy: guideCircleInset)
        let guideCirclePath = UIBezierPath(ovalIn: guideCircleRect)
        guideCirclePath.lineWidth = self.guideWidth

        self.guideColor.setStroke()
        guideCirclePath.stroke()

        let guideLineLength = backgroundCircleRadius * (1.0 - self.guideCircleSizeRatio)
        self.drawGuideLine(a: CGPoint(x: backgroundCircleRect.minX, y: backgroundCircleRect.midY),
                           b: CGPoint(x: backgroundCircleRect.minX + guideLineLength, y: backgroundCircleRect.midY))
        self.drawGuideLine(a: CGPoint(x: backgroundCircleRect.maxX, y: backgroundCircleRect.midY),
                           b: CGPoint(x: backgroundCircleRect.maxX - guideLineLength, y: backgroundCircleRect.midY))
        self.drawGuideLine(a: CGPoint(x: backgroundCircleRect.midX, y: backgroundCircleRect.minY),
                           b: CGPoint(x: backgroundCircleRect.midX, y: backgroundCircleRect.minY + guideLineLength))
        self.drawGuideLine(a: CGPoint(x: backgroundCircleRect.midX, y: backgroundCircleRect.maxY),
                           b: CGPoint(x: backgroundCircleRect.midX, y: backgroundCircleRect.maxY - guideLineLength))

        let length = sqrt(pow(self.bubbleCenter.x, 2.0) + pow(self.bubbleCenter.y, 2.0))
        if length > self.guideCircleSizeRatio - self.bubbleSizeRatio {
            let errorPath = UIBezierPath(ovalIn: backgroundCircleRect)
            errorPath.lineWidth = self.errorWidth

            self.errorColor.setStroke()
            errorPath.stroke()
        }
    }

    private func drawGuideLine(a: CGPoint, b: CGPoint) {
        let path = UIBezierPath()
        path.lineWidth = self.guideWidth

        path.move(to: a)
        path.addLine(to: b)
        path.close()

        self.guideColor.setStroke()
        path.stroke()
    }

}
