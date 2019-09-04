//
//  RewardsIconView.swift
//  breadwallet
//
//  Created by David Seitz Jr on 1/27/19.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//

import UIKit

/// This is an icon that handles animation, meant to be used in the RewardsView.
class RewardsIconView: MultiframeAnimation, AnimatableIcon {

    // MARK: - Properties

    private let imageView = UIImageView()

    /// Animation frames that have been prepared in advance to allow
    /// this icon to play its animation immediately.
    static var preparedAnimationFrames: [UIImage]?

    // MARK: - Setup

    func setUp() {
        setUpSubViews()
        setUpConstraints()
        
        if RewardsView.shouldShowExpandedWithAnimation {
            setUpAnimatedIcon()
        }
        
        setUpStillIcon()
    }

    private func setUpSubViews() {
        addSubview(imageView)
    }

    private func setUpConstraints() {
        imageView.constrain([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor)])
    }

    private func setUpAnimatedIcon() {
        imageView.animationImages = RewardsIconView.preparedAnimationFrames
        imageView.animationDuration = 1
        imageView.animationRepeatCount = 1
    }

    private func setUpStillIcon() {
        imageView.image = UIImage(named: "rewardsIcon-70.gif")
    }

    // MARK: - Convenience Methods

    static func prepareAnimationFrames() {
        guard UserDefaults.shouldShowBRDRewardsAnimation else { return }
        RewardsIconView().setUpAnimationFrames(fileName: "rewardsIcon-",
                                               count: 70,
                                               repeatFirstFrameCount: 0,
                                               fileType: "gif") { animationFrames in
                                                RewardsIconView.preparedAnimationFrames = animationFrames
        }
    }

    // MARK: - AnimatableIcon

    func startAnimating() {
        imageView.startAnimating()
    }
    
    func stopAnimating() {
        imageView.stopAnimating()
    }

}
