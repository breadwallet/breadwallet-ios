//
//  RewardsView.swift
//  breadwallet
//
//  Created by David Seitz Jr on 1/27/19.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//

import UIKit

/// This is a view that is meant to be shown for BRD rewards.
/// It can show as either, expanded or normal (a smaller version).
class RewardsView: UIView {

    // MARK: - Rewards View State

    enum State {
        case expanded
        case normal
    }

    static let expandedSize: CGFloat = 149 + C.padding[4] + 4.5
    static let normalSize: CGFloat = 46 + C.padding[4] + 4.5 //4.5 is to account for negative the iconTopConstraintNormalConstant

    // MARK: - Properties

    private let icon = RewardsIconView()
    private let normalTitle = UILabel(font: .customBody(size: 14), color: .rewardsViewNormalTitle)
    private let expandedTitle = UILabel(font: .customBold(size: 18), color: .rewardsViewExpandedTitle)
    private let expandedBody = UILabel(font: .customBody(size: 14), color: .rewardsViewExpandedBody)
    private var iconTopConstraint: NSLayoutConstraint?
    private var indicatorView = UIImageView()
    private let topPadding = UIView(color: .whiteTint)
    private let bottomPadding = UIView(color: .whiteTint)
    private static var iconTopConstraintNormalConstant: CGFloat = -9.0

    // MARK: Computed

    /// Describes whether this view should show as expanded or normal.
    private var state: RewardsView.State {
        return UserDefaults.shouldShowBRDRewardsAnimation ? .expanded : .normal
    }

    /// Determines if the RewardsView should show in its expanded form and animated.
    static var shouldShowExpandedWithAnimation: Bool {
        return UserDefaults.shouldShowBRDRewardsAnimation
    }

    // MARK: - Initialization

    init() {
        super.init(frame: .zero)
        setup()
    }

    // MARK: - Convenience Methods

    func setup() {
        setUpSubviews()
        setUpConstraints()
        setUpStyle()
        setUpIconIfAppropriate()
    }

    private func setUpSubviews() {
        
        addSubview(icon)
        addSubview(normalTitle)
        addSubview(indicatorView)
        if state == .expanded {
            addSubview(expandedTitle)
            addSubview(expandedBody)
        }
        addSubview(bottomPadding)
        addSubview(topPadding)
    }

    private func setUpConstraints() {
        topPadding.constrainTopCorners(height: C.padding[2])
        let iconWidthAndHeight: CGFloat = 65
        iconTopConstraint = icon.topAnchor.constraint(equalTo: topPadding.bottomAnchor, constant: state == .normal ? RewardsView.iconTopConstraintNormalConstant : 8)
        icon.constrain([
            iconTopConstraint,
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0),
            icon.widthAnchor.constraint(equalToConstant: iconWidthAndHeight),
            icon.heightAnchor.constraint(equalToConstant: iconWidthAndHeight)])
        normalTitle.constrain([
            normalTitle.topAnchor.constraint(equalTo: topPadding.bottomAnchor, constant: 13),
            normalTitle.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: -10)])
        indicatorView.constrain([
            indicatorView.topAnchor.constraint(equalTo: topPadding.bottomAnchor, constant: 17),
            indicatorView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -21)])
        if state == .expanded {
            expandedTitle.constrain([
                expandedTitle.topAnchor.constraint(equalTo: topPadding.bottomAnchor, constant: 25),
                expandedTitle.leadingAnchor.constraint(equalTo: normalTitle.leadingAnchor, constant: 5),
                expandedTitle.widthAnchor.constraint(equalToConstant: 199)])
            expandedBody.constrain([
                expandedBody.topAnchor.constraint(equalTo: expandedTitle.bottomAnchor, constant: 10),
                expandedBody.leadingAnchor.constraint(equalTo: expandedTitle.leadingAnchor),
                expandedBody.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -56)])
        }
        bottomPadding.constrainBottomCorners(height: C.padding[2])
    }

    private func setUpStyle() {
        clipsToBounds = true
        backgroundColor = .white
        normalTitle.text = S.RewardsView.normalTitle
        expandedTitle.text = S.RewardsView.expandedTitle
        expandedBody.text = S.RewardsView.expandedBody
        expandedTitle.numberOfLines = 0
        expandedBody.numberOfLines = 0
        normalTitle.alpha = RewardsView.shouldShowExpandedWithAnimation ? 0 : 1
        indicatorView.alpha = RewardsView.shouldShowExpandedWithAnimation ? 0 : 1
        indicatorView.image = UIImage(named: "RightArrow")
    }

    private func setUpIconIfAppropriate() {
        // If we're not showing the expand/animate sequence, set up the icon now so that it shows
        // right away in its static state. The alternative is that animateIcon() will be called, which
        // sets up and animates the icon.
        if !RewardsView.shouldShowExpandedWithAnimation {
            icon.setUp()
        }
    }
    
    func shrinkView() {
        iconTopConstraint?.constant = RewardsView.iconTopConstraintNormalConstant
        expandedTitle.alpha = 0
        expandedBody.alpha = 0
        normalTitle.alpha = 1
        indicatorView.alpha = 1
    }
    
    func animateIcon() {
        icon.setUp()
        icon.startAnimating()
    }

    // MARK: - UIView's Required Initializer

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
