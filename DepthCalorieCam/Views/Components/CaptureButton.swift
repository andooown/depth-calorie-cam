//
//  CaptureButton.swift
//  DepthCalorieCam
//
//  Created by Yoshikazu Ando on 2019/01/04.
//  Copyright © 2019 Yoshikazu Ando. All rights reserved.
//

import UIKit

@IBDesignable class CaptureButton: UIButton {
    
    @IBInspectable var outerCircleWidth: CGFloat = 6.0
    @IBInspectable var innerCircleMargin: CGFloat = 2.0
    @IBInspectable var animationDuration: Double = 0.4

    private var pathLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        self.setTitle("", for: .normal)

        self.addTarget(self, action: #selector(self.touchDown), for: Event.touchDown)
        self.addTarget(self, action: #selector(self.touchUpInside), for: Event.touchUpInside)
    }

    override func prepareForInterfaceBuilder() {
        self.setup()

        self.setTitle("", for: .normal)
    }

    override func draw(_ rect: CGRect) {
        let outerCircleRect = rect.insetBy(dx: self.outerCircleWidth / 2, dy: self.outerCircleWidth / 2)
        let outerCircle = UIBezierPath(ovalIn: outerCircleRect)
        outerCircle.lineWidth = self.outerCircleWidth
        
        UIColor.white.setStroke()
        
        outerCircle.stroke()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.layoutLayer()
    }

    private func setup() {
        self.layoutLayer()

        self.layer.addSublayer(self.pathLayer)
    }
    
    private func layoutLayer() {
        let inset = self.outerCircleWidth + self.innerCircleMargin
        let pathRect = self.bounds.insetBy(dx: inset, dy: inset)
        self.pathLayer.path = UIBezierPath(roundedRect: pathRect, cornerRadius: pathRect.width / 2.0).cgPath
        
        self.pathLayer.strokeColor = nil
        self.pathLayer.fillColor = UIColor.white.cgColor
    }

    @objc
    private func touchDown(_ sender: UIButton) {
        let animation = CABasicAnimation(keyPath: "fillColor")
        animation.duration = self.animationDuration
        animation.toValue = UIColor.darkGray.cgColor
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        self.pathLayer.add(animation, forKey: "")
    }

    @objc
    private func touchUpInside(_ sender: UIButton) {
        let animation = CABasicAnimation(keyPath: "fillColor")
        animation.duration = self.animationDuration
        animation.toValue = UIColor.white.cgColor
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        self.pathLayer.add(animation, forKey: "darkColor")
    }

}
