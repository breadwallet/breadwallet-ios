//
//  PaperPhraseViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-25.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class HeaderView: UIView, GradientDrawable {
    override func draw(_ rect: CGRect) {
        drawRadialGradient(rect)
    }
}

class StartPaperPhraseViewController: UIViewController {

    private let paperKey =      ShadowButton(title: NSLocalizedString("Write Down Paper Key", comment: "button label"), type: .primary)
    private let illustration =  UIImageView(image: #imageLiteral(resourceName: "PaperKey"))
    private let pencil =        UIImageView(image: #imageLiteral(resourceName: "Pencil"))
    private let explanation =   UILabel.wrapping(font: UIFont.customBody(size: 16.0))
    private let explanationString = NSLocalizedString("Protect your wallet against theft and ensure you can recover your wallet after replacing your phone or updating its software. ", comment: "Paper key explanation text.")
    private let store: Store
    private let header = HeaderView()

    init(store: Store) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        view.backgroundColor = .white
        header.backgroundColor = .brand
        explanation.text = explanationString
        addSubviews()
        addConstraints()
        addButtonActions()
    }

    private func addSubviews() {
        view.addSubview(header)
        header.addSubview(illustration)
        illustration.addSubview(pencil)
        view.addSubview(explanation)
        view.addSubview(paperKey)
    }

    private func addConstraints() {
        header.constrainTopCorners(sidePadding: 0, topPadding: 0)
        header.constrain([
                header.constraint(.height, constant: 220.0)
            ])
        illustration.constrain([
                illustration.constraint(.width, constant: 64.0),
                illustration.constraint(.height, constant: 84.0),
                illustration.constraint(.centerX, toView: header, constant: nil),
                illustration.constraint(.bottom, toView: header, constant: -C.padding[4])
            ])
        pencil.constrain([
                pencil.constraint(.width, constant: 32.0),
                pencil.constraint(.height, constant: 32.0),
                pencil.constraint(.leading, toView: illustration, constant: 44.0),
                pencil.constraint(.top, toView: illustration, constant: -4.0)
            ])
        explanation.constrain([
                explanation.constraint(toBottom: header, constant: C.padding[3]),
                explanation.constraint(.leading, toView: view, constant: C.padding[2]),
                explanation.constraint(.trailing, toView: view, constant: -C.padding[2])
            ])
        paperKey.constrainBottomCorners(sidePadding: C.padding[2], bottomPadding: (C.padding[2] + C.Sizes.buttonHeight))
        paperKey.constrain([
                paperKey.constraint(.height, constant: C.Sizes.buttonHeight)
            ])
    }

    private func addButtonActions() {
        paperKey.addTarget(self, action: #selector(writePaperKeyPressed), for: .touchUpInside)
    }

    @objc private func writePaperKeyPressed() {
        store.perform(action: PaperPhrase.Write())
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
