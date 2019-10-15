//
//  ModalHeaderView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-01.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit

enum ModalHeaderViewStyle {
    case light
    case dark
    case transaction
}

class ModalHeaderView: UIView {

    // MARK: - Public
    var closeCallback: (() -> Void)? {
        didSet { close.tap = closeCallback }
    }
    
    init(title: String, style: ModalHeaderViewStyle, faqInfo: String? = nil, currency: Currency? = nil) {
        self.titleLabel.text = title
        self.style = style
        
        if let faqInfo = faqInfo {
            self.faq = UIButton.buildFaqButton(articleId: faqInfo, currency: currency)
        }

        super.init(frame: .zero)
        setupSubviews()
        addFaqButton()
    }
    
    func setTitle(_ title: String) {
        self.titleLabel.text = title
    }

    // MARK: - Private
    private let titleLabel = UILabel(font: .customBold(size: 17.0))
    private let close = UIButton.close
    private var faq: UIButton?
    private let border = UIView()
    private let buttonSize: CGFloat = 44.0
    private let style: ModalHeaderViewStyle

    private func setupSubviews() {
        addSubview(titleLabel)
        addSubview(close)
        addSubview(border)
        
        titleLabel.constrain([
            titleLabel.constraint(.centerX, toView: self, constant: 0.0),
            titleLabel.constraint(.centerY, toView: self, constant: 0.0) ])
        border.constrainBottomCorners(height: 1.0)
        
        if style == .transaction {
            close.constrain([
                close.constraint(.trailing, toView: self, constant: 0.0),
                close.constraint(.centerY, toView: self, constant: 0.0),
                close.constraint(.height, constant: buttonSize),
                close.constraint(.width, constant: buttonSize) ])
        } else {
            close.constrain([
                close.constraint(.leading, toView: self, constant: 0.0),
                close.constraint(.centerY, toView: self, constant: 0.0),
                close.constraint(.height, constant: buttonSize),
                close.constraint(.width, constant: buttonSize) ])
        }

        backgroundColor = .white

        setColors()
    }

    private func addFaqButton() {
        guard let faq = faq else { return }
        addSubview(faq)
        faq.constrain([
            faq.constraint((style == .transaction) ? .leading : .trailing, toView: self, constant: 0.0),
            faq.constraint(.centerY, toView: self, constant: 0.0),
            faq.constraint(.height, constant: buttonSize),
            faq.constraint(.width, constant: buttonSize) ])
    }

    private func setColors() {
        switch style {
        case .light:
            titleLabel.textColor = .white
            close.tintColor = .white
            faq?.tintColor = .white
        case .dark:
            border.backgroundColor = .secondaryShadow
            faq?.tintColor = .lightGray
        case .transaction:
            titleLabel.font = .customBody(size: 16.0)
            titleLabel.textColor = .darkGray
            close.tintColor = .lightGray
            faq?.tintColor = .lightGray
            border.backgroundColor = .clear
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
