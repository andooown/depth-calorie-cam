//
//  ResultViewController.swift
//  DepthCalorieCam
//
//  Created by Yoshikazu Ando on 2019/02/03.
//  Copyright © 2019 Yoshikazu Ando. All rights reserved.
//

import UIKit
import AVFoundation

class ResultViewController: UIViewController {
    
    @IBOutlet weak var captureImageView: UIImageView!
    @IBOutlet weak var calorieLabel: UILabel!
    @IBOutlet weak var backButton: UIButton! {
        didSet {
            self.backButton.layer.borderColor = self.backButton.titleColor(for: .normal)?.cgColor
            self.backButton.layer.borderWidth = 1.0

            self.backButton.layer.cornerRadius = self.backButton.bounds.height * 0.1
        }
    }
    
    var baseImage: UIImage?
    var estimationResults: [EstimationResult]?
    var didCloseResultCallback: (() -> Void)?

    private var rectViews = [RectView]()
    private var imageViews = [ResultImageView]()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.setupNavigationBar()
        self.setupResult()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        self.layoutResult()
    }

    private func setupNavigationBar() {
        let closeButtonItem = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(self.closeButtonItemTapped))
        self.navigationItem.rightBarButtonItem = closeButtonItem
    }

    private func setupResult() {
        guard let baseImage = self.baseImage else { return }
        self.captureImageView.image = baseImage

        guard let estimationResults = self.estimationResults else { return }
        var calorie = 0.0
        for (index, result) in estimationResults.enumerated() {
            if let resultCalorie = result.calorie {
                calorie += resultCalorie
            }

            let rectView = RectView(frame: CGRect.zero)
            let hue = 1.0 / Double(estimationResults.count) * Double(index)
            rectView.borderColor = UIColor(hue: CGFloat(hue), saturation: 0.7, brightness: 1.0, alpha: 1.0).cgColor
            self.rectViews.append(rectView)

            let imageView = ResultImageView(frame: CGRect.zero)
            imageView.estimationResult = result
            imageView.resultImageViewTappedHandler = { [weak self] in
                guard let self = self,
                      let detailViewController = UIStoryboard(name: "ResultDetailViewController", bundle: nil).instantiateInitialViewController() as? ResultDetailViewController else { return }
                detailViewController.estimationResult = result

                self.present(detailViewController, animated: true)
            }
            self.imageViews.append(imageView)
        }

        self.calorieLabel.text = String(format: "%.1f kcal", calorie)
        imageViews.forEach { self.view.addSubview($0) }
        rectViews.forEach { self.view.addSubview($0) }
    }

    private func layoutResult() {
        guard let baseImage = self.baseImage, let estimationResults = self.estimationResults else { return }

        let baseImageRect = AVMakeRect(aspectRatio: baseImage.size, insideRect: self.captureImageView.frame)
        for (index, result) in estimationResults.enumerated() {
            var resultRect = result.normalizedRect.denormalizedRect(in: baseImageRect.size)
            resultRect.origin.x += baseImageRect.origin.x
            resultRect.origin.y += baseImageRect.origin.y

            self.imageViews[index].frame = resultRect
            self.rectViews[index].frame = resultRect
        }
    }

    @objc
    func closeButtonItemTapped() {
        self.navigationController?.dismiss(animated: true) { [weak self] in
            self?.didCloseResultCallback?()
        }
    }
    
}
