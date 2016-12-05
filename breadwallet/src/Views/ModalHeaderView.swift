//
//  ModalHeaderView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-01.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class ModalHeaderView: UIView {

    var closeCallback: (() -> Void)?
    var faqCallback: (() -> Void)?

    init(title: String, isFaqHidden: Bool) {
        self.title.text = title
        faq.isHidden = isFaqHidden
        super.init(frame: .zero)
        setupSubviews()
    }

    private let title = UILabel(font: .customBold(size: 17.0))
    private let close = UIButton.close()
    private let faq = UIButton.faq()
    private let border = UIView()
    private let buttonSize: CGFloat = 44.0

    private func setupSubviews() {
        addSubview(title)
        addSubview(close)
        addSubview(faq)
        addSubview(border)
        close.constrain([
                close.constraint(.leading, toView: self, constant: 0.0),
                close.constraint(.centerY, toView: self, constant: 0.0),
                close.constraint(.height, constant: buttonSize),
                close.constraint(.width, constant: buttonSize)
            ])
        title.constrain([
                title.constraint(.centerX, toView: self, constant: 0.0),
                title.constraint(.centerY, toView: self, constant: 0.0)
            ])
        faq.constrain([
                faq.constraint(.trailing, toView: self, constant: 0.0),
                faq.constraint(.centerY, toView: self, constant: 0.0),
                faq.constraint(.height, constant: buttonSize),
                faq.constraint(.width, constant: buttonSize)
            ])
        border.constrain([
                border.constraint(.height, constant: 1.0)
            ])
        border.constrainBottomCorners(sidePadding: 0, bottomPadding: 0)
        border.backgroundColor = .secondaryShadow

        close.addTarget(self, action: #selector(ModalHeaderView.closeTapped), for: .touchUpInside)
        faq.addTarget(self, action: #selector(ModalHeaderView.faqTapped), for: .touchUpInside)
    }

    @objc private func closeTapped() {
        closeCallback?()
    }

    @objc private func faqTapped() {
        faqCallback?()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
