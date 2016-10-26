//
//  PaperPhraseViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-25.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class StartPaperPhraseViewController: UIViewController {

    private let paperKey = UIButton.makeSolidButton(title: "Write Down Paper Key")
    private let skip = UIButton.makeOutlineButton(title: "Skip")

    private let store: Store

    init(store: Store) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        view.backgroundColor = .white
        addSubviews()
        addConstraints()
        addButtonActions()
    }

    private func addSubviews() {
        view.addSubview(paperKey)
        view.addSubview(skip)
    }

    private func addConstraints() {
        skip.constrain([
                skip.constraint(.leading, toView: view, constant: Constants.Padding.double),
                skip.constraint(.bottom, toView: view, constant: -Constants.Padding.triple),
                skip.constraint(.trailing, toView: view, constant: -Constants.Padding.double),
                skip.constraint(.height, constant: Constants.Sizes.buttonHeight)
            ])
        paperKey.constrain([
                paperKey.constraint(toTop: skip, constant: -Constants.Padding.double),
                paperKey.constraint(.centerX, toView: skip, constant: nil),
                paperKey.constraint(.width, toView: skip, constant: nil),
                paperKey.constraint(.height, constant: Constants.Sizes.buttonHeight)
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
