//
//  ResultImageView.swift
//  DepthCalorieCam
//
//  Created by Yoshikazu Ando on 2019/02/05.
//  Copyright © 2019 Yoshikazu Ando. All rights reserved.
//

import UIKit

class ResultImageView: UIImageView {

    var estimationResult: EstimationResult? {
        didSet {
            self.image = self.estimationResult?.rgbImage
        }
    }
    var resultImageViewTappedHandler: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        self.setup()
    }

    fileprivate func setup() {
        self.backgroundColor = .clear
        self.contentMode = .scaleToFill

        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.imageViewTapped(_:))))
        self.isUserInteractionEnabled = true
    }

    @objc
    private func imageViewTapped(_ sender: UITapGestureRecognizer) {
        self.resultImageViewTappedHandler?()
    }

}
