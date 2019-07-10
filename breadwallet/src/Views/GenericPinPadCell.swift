//
//  GenericPinPadCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-15.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit

// swiftlint:disable unused_setter_value

class GenericPinPadCell: UICollectionViewCell {

    var text: String? {
        didSet {
            if let specialKey = PinPadViewController.SpecialKeys(rawValue: text!) {
                imageView.image = specialKey.image(forStyle: style)
                label.text = ""
            } else {
                imageView.image = nil
                label.text = text
            }
            setAppearance()
        }
    }

    override var isHighlighted: Bool {
        didSet {
            guard !text.isNilOrEmpty else { return } //We don't want the blank cell to highlight
            setAppearance()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    internal var label = UILabel(font: .customBody(size: 28.0))
    internal let imageView = UIImageView()
    let masks: [UIView] = (0..<4).map { _ in UIView(color: .darkBackground) }
    var style: PinPadStyle = .clear

    private func setup() {
        setAppearance()
        label.textAlignment = .center
        addSubview(label)
        addSubview(imageView)
        imageView.contentMode = .center
        masks.forEach { self.addSubview($0) }
        addConstraints()
    }

    func addConstraints() {
        imageView.constrain([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor)])
        label.constrain(toSuperviewEdges: nil)

        masks[0].constrain([
            masks[0].leadingAnchor.constraint(equalTo: leadingAnchor),
            masks[0].topAnchor.constraint(equalTo: topAnchor),
            masks[0].bottomAnchor.constraint(equalTo: bottomAnchor),
            masks[0].trailingAnchor.constraint(equalTo: imageView.leadingAnchor)])
        masks[1].constrain([
            masks[1].leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            masks[1].topAnchor.constraint(equalTo: topAnchor),
            masks[1].bottomAnchor.constraint(equalTo: imageView.topAnchor),
            masks[1].trailingAnchor.constraint(equalTo: imageView.trailingAnchor)])
        masks[2].constrain([
            masks[2].leadingAnchor.constraint(equalTo: imageView.trailingAnchor),
            masks[2].topAnchor.constraint(equalTo: topAnchor),
            masks[2].bottomAnchor.constraint(equalTo: bottomAnchor),
            masks[2].trailingAnchor.constraint(equalTo: trailingAnchor)])
        masks[3].constrain([
            masks[3].leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            masks[3].topAnchor.constraint(equalTo: imageView.bottomAnchor),
            masks[3].bottomAnchor.constraint(equalTo: bottomAnchor),
            masks[3].trailingAnchor.constraint(equalTo: imageView.trailingAnchor)])
    }

    override var isAccessibilityElement: Bool {
        get {
            return true
        }
        set { }
    }

    override var accessibilityLabel: String? {
        get {
            return label.text
        }
        set { }
    }

    override var accessibilityTraits: UIAccessibilityTraits {
        get {
            return UIAccessibilityTraits.staticText
        }
        set { }
    }

    func setAppearance() {}

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
