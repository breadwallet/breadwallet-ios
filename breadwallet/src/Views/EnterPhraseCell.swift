//
//  EnterPhraseCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-02-24.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class EnterPhraseCell : UICollectionViewCell {

    //MARK: - Public
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    var index: Int? {
        didSet {
            guard let index = index else { return }
            label.text = "\(index + 1)"
        }
    }
    private(set) var text: String?

    var didTapPrevious: (() -> Void)? {
        didSet {
            previousField.tap = didTapPrevious
        }
    }

    var didTapNext: (() -> Void)? {
        didSet {
            nextField.tap = didTapNext
        }
    }

    var didTapDone: (() -> Void)? {
        didSet {
            done.tap = didTapDone
        }
    }

    //MARK: - Private
    let textField = UITextField()
    private let label = UILabel(font: .customBody(size: 13.0), color: .secondaryShadow)
    private let separator = UIView(color: .secondaryShadow)
    private let nextField = UIButton.icon(image: #imageLiteral(resourceName: "RightArrow"), accessibilityLabel: S.RecoverWallet.rightArrow)
    private let previousField = UIButton.icon(image: #imageLiteral(resourceName: "LeftArrow"), accessibilityLabel: S.RecoverWallet.leftArrow)
    private let done = UIButton(type: .system)

    private func setup() {
        contentView.addSubview(textField)
        contentView.addSubview(separator)
        contentView.addSubview(label)

        textField.constrain([
            textField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            textField.topAnchor.constraint(equalTo: contentView.topAnchor),
            textField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor) ])
        separator.constrain([
            separator.leadingAnchor.constraint(equalTo: textField.leadingAnchor, constant: C.padding[1]),
            separator.topAnchor.constraint(equalTo: textField.bottomAnchor),
            separator.trailingAnchor.constraint(equalTo: textField.trailingAnchor, constant: -C.padding[1]),
            separator.heightAnchor.constraint(equalToConstant: 1.0) ])
        label.constrain([
            label.leadingAnchor.constraint(equalTo: separator.leadingAnchor),
            label.topAnchor.constraint(equalTo: separator.bottomAnchor),
            label.trailingAnchor.constraint(equalTo: separator.trailingAnchor) ])
        setData()
    }

    private func setData() {
        label.textAlignment = .center
        textField.inputAccessoryView = accessoryView
        textField.autocorrectionType = .no
        textField.textAlignment = .center
        textField.autocapitalizationType = .none
        textField.tintColor = C.defaultTintColor
        previousField.tintColor = .secondaryGrayText
        nextField.tintColor = .secondaryGrayText
        done.setTitle(S.RecoverWallet.done, for: .normal)
    }

    private var accessoryView: UIView {
        let view = UIView(color: .secondaryButton)
        view.frame = CGRect(x: 0, y: 0, width: 375, height: 44)
        let separator = UIView(color: .secondaryShadow)
        view.addSubview(separator)
        view.addSubview(previousField)
        view.addSubview(nextField)
        view.addSubview(done)

        separator.constrainTopCorners(height: 1.0)
        previousField.constrain([
            previousField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            previousField.topAnchor.constraint(equalTo: view.topAnchor),
            previousField.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            previousField.widthAnchor.constraint(equalToConstant: 44.0) ])

        nextField.constrain([
            nextField.leadingAnchor.constraint(equalTo: previousField.trailingAnchor),
            nextField.topAnchor.constraint(equalTo: view.topAnchor),
            nextField.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            nextField.widthAnchor.constraint(equalToConstant: 44.0) ])

        done.constrain([
            done.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]),
            done.topAnchor.constraint(equalTo: view.topAnchor),
            done.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            done.widthAnchor.constraint(equalToConstant: 44.0) ])

        return view
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
