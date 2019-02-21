//
//  PaperPhraseViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-25.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

typealias StartPaperPhraseDismissedCallback = (() -> Void)

class StartPaperPhraseViewController: UIViewController {
    
    init(eventContext: EventContext, dismissAction: Action?, callback: @escaping () -> Void) {
        self.writePaperKeyCallback = callback
        self.eventContext = eventContext
        self.dismissAction = dismissAction
        let buttonTitle = UserDefaults.walletRequiresBackup ? S.StartPaperPhrase.buttonTitle : S.StartPaperPhrase.againButtonTitle
        writePaperKeyButton = BRDButton(title: buttonTitle, type: .primary)
        super.init(nibName: nil, bundle: nil)
    }

    private let writePaperKeyButton: BRDButton
    private let illustration = UIImageView(image: #imageLiteral(resourceName: "PaperKey"))
    private let explanation = UILabel.wrapping(font: UIFont.customBody(size: 16.0), color: .white)
    private let header = RadialGradientView(backgroundColor: .pink, offset: 64.0)
    private let footer = UILabel.wrapping(font: .customBody(size: 13.0), color: .white)
    private let writePaperKeyCallback: () -> Void
    private var eventContext: EventContext = .none
    private var dismissAction: Action?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        trackEvent(event: .appeared)
    }
    
    override func viewDidLoad() {
        view.backgroundColor = .darkBackground
        explanation.text = S.StartPaperPhrase.body
        addSubviews()
        addConstraints()
        
        writePaperKeyButton.tap = { [weak self] in
            self?.trackEvent(event: .writeDownButton)
            self?.writePaperKeyCallback()
        }
        
        if let writePaperPhraseDate = UserDefaults.writePaperPhraseDate {
            let df = DateFormatter()
            df.setLocalizedDateFormatFromTemplate("MMMM d, yyyy")
            footer.text = String(format: S.StartPaperPhrase.date, df.string(from: writePaperPhraseDate))
        }

        setUpCloseButton()
        setUpFAQButton()
    }

    private func setUpCloseButton() {
        let closeButton = UIButton.close
        
        closeButton.tintColor = .white
        closeButton.tap = { [weak self] in
            self?.trackEvent(event: .dismissed)

            if let action = self?.dismissAction {
                Store.perform(action: action)
            }
        }
        
        self.navigationItem.leftBarButtonItems = [UIBarButtonItem.negativePadding, UIBarButtonItem(customView: closeButton)]
    }
    
    private func setUpFAQButton() {
        let faqButton = UIButton.buildFaqButton(articleId: ArticleIds.paperKey, currency: nil) { [unowned self] in
            self.trackEvent(event: .helpButton)
        }
        self.navigationItem.rightBarButtonItems = [UIBarButtonItem.negativePadding, UIBarButtonItem(customView: faqButton)]
    }
    
    private func addSubviews() {
        view.addSubview(header)
        header.addSubview(illustration)
        view.addSubview(explanation)
        view.addSubview(writePaperKeyButton)
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
        explanation.constrain([
            explanation.constraint(toBottom: header, constant: C.padding[3]),
            explanation.constraint(.leading, toView: view, constant: C.padding[2]),
            explanation.constraint(.trailing, toView: view, constant: -C.padding[2]) ])
        writePaperKeyButton.constrain([
            writePaperKeyButton.leadingAnchor.constraint(equalTo: footer.leadingAnchor),
            writePaperKeyButton.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -C.padding[2]),
            writePaperKeyButton.trailingAnchor.constraint(equalTo: footer.trailingAnchor),
            writePaperKeyButton.constraint(.height, constant: C.Sizes.buttonHeight) ])
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

extension StartPaperPhraseViewController: Trackable {
    func trackEvent(event: Event) {
        saveEvent(context: eventContext,
                  screen: .paperKeyIntro,
                  event: event)
    }
}
