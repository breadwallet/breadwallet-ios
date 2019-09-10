//
//  PhraseView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-26.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit

class PhraseView: UIView {

    private let phrase: String
    private let label = UILabel()

    static let defaultSize = CGSize(width: 128.0, height: 88.0)

    var xConstraint: NSLayoutConstraint?

    init(phrase: String) {
        self.phrase = phrase
        super.init(frame: CGRect())
        setupSubviews()
    }

    private func setupSubviews() {
        addSubview(label)
        label.constrain(toSuperviewEdges: UIEdgeInsets(top: C.padding[1], left: C.padding[2], bottom: -C.padding[1], right: -C.padding[2]))
        label.textColor = .white
        label.text = phrase
        label.font = UIFont.customBold(size: 16.0)
        label.textAlignment = .center
        backgroundColor = .pink
        layer.cornerRadius = 10.0
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
