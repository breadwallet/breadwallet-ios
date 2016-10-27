//
//  ConfirmPaperPhraseViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-27.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class ConfirmPaperPhraseViewController: UIViewController {

    private let label =                 UILabel.makeWrappingLabel(font: UIFont.preferredFont(forTextStyle: .body))
    private let separator =             UIView()
    private let confirmFirstPhrase =    ConfirmPhrase(text: "Word 3")
    private let confirmSecondPhrase =   ConfirmPhrase(text: "Word 8")
    
    private let store: Store

    init(store: Store) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        view.backgroundColor = .white
        label.text = "Prove you wrote down your paper key by answering the following questions."
        separator.backgroundColor = .darkGray
        addSubviews()
        addConstraints()
        addButtonActions()
    }

    private func addSubviews() {
        view.addSubview(label)
        view.addSubview(separator)
        view.addSubview(confirmFirstPhrase)
        view.addSubview(confirmSecondPhrase)
    }

    private func addConstraints() {
        label.constrainTopCorners(sidePadding: Constants.Padding.double, topPadding: Constants.Padding.triple, topLayoutGuide: topLayoutGuide)
        separator.constrain([
                separator.constraint(toBottom: label, constant: Constants.Padding.double),
                separator.constraint(.height, constant: 1.0),
                separator.constraint(.width, toView: view, constant: 0.0)
            ])
        confirmFirstPhrase.constrain([
                confirmFirstPhrase.constraint(toBottom: separator, constant: 0.0),
                confirmFirstPhrase.constraint(.width, toView: view, constant: 0.0),
                confirmFirstPhrase.constraint(.centerX, toView: view, constant: 0.0)
            ])
        confirmSecondPhrase.constrain([
                confirmSecondPhrase.constraint(toBottom: confirmFirstPhrase, constant: 0.0),
                confirmSecondPhrase.constraint(.width, toView: view, constant: 0.0),
                confirmSecondPhrase.constraint(.centerX, toView: view, constant: 0.0)
            ])
    }

    private func addButtonActions() {

    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
