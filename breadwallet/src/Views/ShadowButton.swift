//
//  ShadowButton.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-15.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class ShadowButton: UIControl {

    private let title: String
    private let container = UIView()
    private let shadowView = UIView()
    private let shadowSidePadding: CGFloat = 32.0
    private let shadowYOffset: CGFloat = 4.0

    override var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                UIView.animate(withDuration: 0.04, animations: {
                    let shrink = CATransform3DMakeScale(0.97, 0.97, 1.0)
                    let translate = CATransform3DTranslate(shrink, 0, 4.0, 0)
                    self.container.layer.transform = translate
                })
            } else {
                UIView.animate(withDuration: 0.04, animations: {
                    self.container.transform = CGAffineTransform.identity
                })
            }
        }
    }

    init(title: String) {
        self.title = title
        super.init(frame: CGRect.zero)
        setupViews()
    }

    private func setupViews() {
        addShadowView()
        addContent()
    }

    private func addShadowView() {
        addSubview(shadowView)
        shadowView.constrainBottomCorners(sidePadding: shadowSidePadding, bottomPadding: 0.0)
        shadowView.constrain([
            NSLayoutConstraint(item: shadowView, attribute: .height, relatedBy: .equal, toItem: self, attribute: .height, multiplier: 0.5, constant: 1.0)
            ])
        shadowView.layer.cornerRadius = 4.0
        shadowView.layer.shadowColor = UIColor.black.cgColor
        shadowView.layer.shadowOpacity = 0.5
        shadowView.layer.shadowOffset = CGSize(width: 0, height: 4)
        shadowView.backgroundColor = .white
        shadowView.isUserInteractionEnabled = false
    }

    private func addContent() {
        addSubview(container)
        container.backgroundColor = .primaryButton
        container.layer.cornerRadius = 4.0
        container.isUserInteractionEnabled = false
        container.constrain(toSuperviewEdges: nil)

        let label = UILabel()
        container.addSubview(label)
        label.constrain(toSuperviewEdges: nil)
        label.text = title
        label.textColor = .white
        label.textAlignment = .center
        label.isUserInteractionEnabled = false
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
