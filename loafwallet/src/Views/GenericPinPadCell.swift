//
//  GenericPinPadCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-15.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class GenericPinPadCell : UICollectionViewCell {

    var text: String? {
        didSet {
            if text == deleteKeyIdentifier {
                imageView.image = #imageLiteral(resourceName: "Delete")
                topLabel.text = ""
                centerLabel.text = ""
            } else {
                imageView.image = nil
                topLabel.text = text
                centerLabel.text = text
            }
            setAppearance()
            setSublabel()
        }
    }

    let sublabels = [
        "2": "ABC",
        "3": "DEF",
        "4": "GHI",
        "5": "JKL",
        "6": "MNO",
        "7": "PORS",
        "8": "TUV",
        "9": "WXYZ"
    ]

    override var isHighlighted: Bool {
        didSet {
            guard text != "" else { return } //We don't want the blank cell to highlight
            setAppearance()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    internal let topLabel = UILabel(font: .customBody(size: 28.0))
    internal let centerLabel = UILabel(font: .customBody(size: 28.0))
    internal let sublabel = UILabel(font: .customBody(size: 11.0))
    internal let imageView = UIImageView()

    private func setup() {
        setAppearance()
        topLabel.textAlignment = .center
        centerLabel.textAlignment = .center
        sublabel.textAlignment = .center
        addSubview(topLabel)
        addSubview(centerLabel)
        addSubview(sublabel)
        addSubview(imageView)
        imageView.contentMode = .center
        addConstraints()
    }

    func addConstraints() {
        imageView.constrain(toSuperviewEdges: nil)
        centerLabel.constrain(toSuperviewEdges: nil)
        topLabel.constrain([
            topLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            topLabel.topAnchor.constraint(equalTo: topAnchor, constant: 2.5) ])
        sublabel.constrain([
            sublabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            sublabel.topAnchor.constraint(equalTo: topLabel.bottomAnchor, constant: -3.0) ])
    }

    override var isAccessibilityElement: Bool {
        get {
            return true
        }
        set { }
    }

    override var accessibilityLabel: String? {
        get {
            return topLabel.text
        }
        set { }
    }

    override var accessibilityTraits: UIAccessibilityTraits {
        get {
            return UIAccessibilityTraitStaticText
        }
        set { }
    }

    func setAppearance() {}
    func setSublabel() {}

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
