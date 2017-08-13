//
//  PaperPhraseViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-25.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class StartPaperPhraseViewController : UIViewController {

    init(store: Store, callback: @escaping () -> Void) {
        self.store = store
        self.callback = callback
        let buttonTitle = UserDefaults.walletRequiresBackup ? S.StartPaperPhrase.buttonTitle : S.StartPaperPhrase.againButtonTitle
        button = ShadowButton(title: buttonTitle, type: .primary)
        super.init(nibName: nil, bundle: nil)
    }

    private let button: ShadowButton
    private let illustration = UIImageView(image: #imageLiteral(resourceName: "PaperKey"))
    private let pencil = UIImageView(image: #imageLiteral(resourceName: "Pencil"))
    private let explanation = UILabel.wrapping(font: UIFont.customBody(size: 16.0))
    private let store: Store
    private let header = RadialGradientView(backgroundColor: .pink, offset: 64.0)
    private let footer = UILabel.wrapping(font: .customBody(size: 13.0), color: .secondaryGrayText)
    private let callback: () -> Void

    override func viewDidLoad() {
        view.backgroundColor = .white
        explanation.text = S.StartPaperPhrase.body
        addSubviews()
        addConstraints()
        button.tap = { [weak self] in
            self?.callback()
        }
        if let writePaperPhraseDate = UserDefaults.writePaperPhraseDate {
            let df = DateFormatter()
            df.setLocalizedDateFormatFromTemplate("MMMM d, yyyy")
            footer.text = String(format: S.StartPaperPhrase.date, df.string(from: writePaperPhraseDate))
        }
    }

    private func addSubviews() {
        view.addSubview(header)
        header.addSubview(illustration)
        illustration.addSubview(pencil)
        view.addSubview(explanation)
        view.addSubview(button)
        view.addSubview(footer)
    }

    private func addConstraints() {
        header.constrainTopCorners(sidePadding: 0, topPadding: 0)
        header.constrain([
            header.constraint(.height, constant: 220.0) ])
        illustration.constrain([
            illustration.constraint(.width, constant: 64.0),
            illustration.constraint(.height, constant: 84.0),
            illustration.constraint(.centerX, toView: header, constant: nil),
            illustration.constraint(.bottom, toView: header, constant: -C.padding[4]) ])
        pencil.constrain([
            pencil.constraint(.width, constant: 32.0),
            pencil.constraint(.height, constant: 32.0),
            pencil.constraint(.leading, toView: illustration, constant: 44.0),
            pencil.constraint(.top, toView: illustration, constant: -4.0) ])
        explanation.constrain([
            explanation.constraint(toBottom: header, constant: C.padding[3]),
            explanation.constraint(.leading, toView: view, constant: C.padding[2]),
            explanation.constraint(.trailing, toView: view, constant: -C.padding[2]) ])
        button.constrain([
            button.leadingAnchor.constraint(equalTo: footer.leadingAnchor),
            button.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -C.padding[2]),
            button.trailingAnchor.constraint(equalTo: footer.trailingAnchor),
            button.constraint(.height, constant: C.Sizes.buttonHeight) ])
        footer.constrain([
            footer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            footer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -C.padding[2]),
            footer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]) ])
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
