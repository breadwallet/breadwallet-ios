//
//  CellHighlightView.swift
//  breadwallet
//
//  Created by David Seitz Jr on 1/30/19.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//

import UIKit

/**
 *  Can be added to a home screen wallet cell in order to highlight it. (e.g., with a shimmer animation)
 */
class HomeScreenCellHighlightView: MultiframeAnimation, AnimatableIcon {

    private var imageView = UIImageView()
    private var shouldAnimate: Bool = false

    func setUp() {
        setUpSubviews()
        setUpConstraints()
        setUpAnimation()
    }

    func highlight() {
        shouldAnimate = true
        startAnimating()
    }
    
    func unhighlight() {
        shouldAnimate = false
        stopAnimating()
    }
    
    private func setUpSubviews() {
        addSubview(imageView)
    }

    private func setUpConstraints() {
        imageView.constrain([imageView.topAnchor.constraint(equalTo: topAnchor),
                             imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
                             imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
                             imageView.trailingAnchor.constraint(equalTo: trailingAnchor)])
    }

    private func setUpAnimation() {
        guard imageView.animationImages == nil else {
            return
        }
        
        // These animation frames make a shimmer animation.
        // We could look into doing this programmatically here: https://www.yudiz.com/facebook-shimmer-animation-swift-4/.
        setUpAnimationFrames(fileName: "CellHighlight-", count: 86, repeatFirstFrameCount: 43, fileType: "png") { [unowned self] animationFrames in
            self.imageView.animationImages = animationFrames
            self.imageView.animationDuration = 2.0
            self.imageView.animationRepeatCount = 0
            
            if self.shouldAnimate {
                self.startAnimating()
            }
        }
    }

    func startAnimating() {
        guard imageView.animationImages != nil else { return }
        imageView.startAnimating()
    }

    func stopAnimating() {
        imageView.stopAnimating()
    }
}
