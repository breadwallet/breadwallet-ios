//
//  MenuButton.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-30.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class MenuButton: UIControl {

    private let type: MenuButtonType
    private let label = UILabel.init(font: .customBody(size: 16.0))
    private let image = UIImageView()

    init(type: MenuButtonType) {
        self.type = type
        super.init(frame: .zero)
        setupViews()
    }

    private func setupViews() {

        addSubview(label)
        label.constrain([
                label.constraint(.centerY, toView: self, constant: 0.0),
                label.constraint(.leading, toView: self, constant: C.padding[2])
            ])
        label.text = type.title

        addSubview(image)
        image.constrain([
                image.constraint(.centerY, toView: self, constant: 0.0),
                image.constraint(.trailing, toView: self, constant: -C.padding[2]),
                image.constraint(.width, constant: 16.0),
                image.constraint(.height, constant: 16.0)
            ])
        image.image = type.image

    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
