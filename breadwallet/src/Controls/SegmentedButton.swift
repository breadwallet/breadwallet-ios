//
//  SegmentedButton.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-02-21.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import UIKit

enum SegmentedButtonType {
    case left
    case right
}

class SegmentedButton: UIControl {

    // MARK: - Public
    init(title: String, type: SegmentedButtonType) {
        self.title = title
        self.type = type
        super.init(frame: .zero)
        accessibilityLabel = title
        setupViews()
    }

    // MARK: - Private
    private let title: String
    private let type: SegmentedButtonType
    private let label = UILabel(font: .customMedium(size: 13.0), color: .white)

    override var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                backgroundColor = UIColor(white: 1.0, alpha: 0.4)
            } else {
                backgroundColor = .clear
            }
        }
    }

    private func setupViews() {
        addSubview(label)
        label.constrain(toSuperviewEdges: nil)
        label.textAlignment = .center
        label.text = title
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
