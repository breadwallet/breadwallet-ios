//
//  PaperPhraseViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-25.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class StartPaperPhraseViewController: UIViewController {

    private let paperKey =      ShadowButton(title: NSLocalizedString("Write Down Paper Key", comment: "button label"), type: .primary)
    private let skip =          ShadowButton(title: NSLocalizedString("Skip", comment: "button label"), type: .secondary)
    private let illustration =  UIImageView(image: #imageLiteral(resourceName: "PaperKey"))
    private let explanation =   UILabel.wrapping(font: UIFont.customBody(size: 16.0))
    private let explanationString = "Protect your wallet against theft and ensure you can recover your wallet after replacing your phone or updating it’s software. "
    private let linkString = "LEARN MORE"
    private let store: Store

    init(store: Store) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        view.backgroundColor = .white
        setupExplanation()
        addSubviews()
        addConstraints()
        addButtonActions()
    }

    private func setupExplanation() {
        let attributedString = NSMutableAttributedString(string: explanationString,
                                                         attributes: [NSFontAttributeName: UIFont.customBody(size: 16.0)])
        let link = NSAttributedString(string: linkString,
                                      attributes: [NSForegroundColorAttributeName: UIColor.brand])
        attributedString.append(link)
        explanation.attributedText = attributedString
    }

    private func addSubviews() {
        view.addSubview(illustration)
        view.addSubview(explanation)
        view.addSubview(paperKey)
        view.addSubview(skip)
    }

    private func addConstraints() {
        illustration.constrain([
                illustration.constraint(.width, constant: 96.0),
                illustration.constraint(.height, constant: 88.0),
                illustration.constraint(.centerX, toView: view, constant: nil),
                NSLayoutConstraint(item: illustration, attribute: .top, relatedBy: .equal, toItem: topLayoutGuide, attribute: .bottom, multiplier: 1.0, constant: C.padding[4])
            ])
        explanation.constrain([
                explanation.constraint(toBottom: illustration, constant: C.padding[3]),
                explanation.constraint(.leading, toView: view, constant: C.padding[2]),
                explanation.constraint(.trailing, toView: view, constant: -C.padding[2])
            ])
        skip.constrain([
                skip.constraint(.leading, toView: view, constant: C.padding[2]),
                skip.constraint(.bottom, toView: view, constant: -C.padding[3]),
                skip.constraint(.trailing, toView: view, constant: -C.padding[2]),
                skip.constraint(.height, constant: C.Sizes.buttonHeight)
            ])
        paperKey.constrain([
                paperKey.constraint(toTop: skip, constant: -C.padding[2]),
                paperKey.constraint(.centerX, toView: skip, constant: nil),
                paperKey.constraint(.width, toView: skip, constant: nil),
                paperKey.constraint(.height, constant: C.Sizes.buttonHeight)
            ])
    }

    private func addButtonActions() {
        skip.addTarget(self, action: #selector(skipPressed), for: .touchUpInside)
        paperKey.addTarget(self, action: #selector(writePaperKeyPressed), for: .touchUpInside)
    }

    @objc private func skipPressed() {
        store.perform(action: HideStartFlow())
    }

    @objc private func writePaperKeyPressed() {
        store.perform(action: PaperPhrase.Write())
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
