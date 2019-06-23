//
//  RectView.swift
//  DepthCalorieCam
//
//  Created by Yoshikazu Ando on 2019/02/05.
//  Copyright © 2019 Yoshikazu Ando. All rights reserved.
//

import UIKit

class RectView: UIView {

    var borderColor: CGColor = UIColor.white.cgColor {
        didSet {
            self.layer.borderColor = self.borderColor
        }
    }
    var borderWidth: CGFloat = 3.0 {
        didSet {
            self.layer.borderWidth = self.borderWidth
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        self.setup()
    }

    fileprivate func setup() {
        self.layer.borderColor = self.borderColor
        self.layer.borderWidth = self.borderWidth

        self.isUserInteractionEnabled = false
    }

}
