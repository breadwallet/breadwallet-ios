//
//  PaperPhraseViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-26.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class WritePaperPhraseViewController: UIViewController {

    private let store: Store
    private let walletManager: WalletManager
    private let pin: String
    private let label = UILabel.wrapping(font: UIFont.customBody(size: 16.0))
    private let stepLabel = UILabel.wrapping(font: UIFont.customMedium(size: 13.0))
    private let header = RadialGradientView(backgroundColor: .pink)
    
    private lazy var phraseViews: [PhraseView] = {
        guard let phraseString = self.walletManager.seedPhrase(pin: self.pin) else { return [] }
        let words = phraseString.components(separatedBy: " ")
        return words.map { PhraseView(phrase: $0) }
    }()
    //This is awkwardly named because nextResponder is now named next is swift 3 :(,
    private let proceed = ShadowButton(title: S.WritePaperPhrase.next, type: .secondary)
    private let previous = ShadowButton(title: S.WritePaperPhrase.previous, type: .secondary)
    private var proceedWidth: NSLayoutConstraint?
    private var previousWidth: NSLayoutConstraint?

    private var phraseOffscreenOffset: CGFloat {
        return view.bounds.width/2.0 + PhraseView.defaultSize.width/2.0
    }
    private var currentPhraseIndex = 0 {
        didSet {
            stepLabel.text = String(format: S.WritePaperPhrase.step, currentPhraseIndex + 1, phraseViews.count)
        }
    }

    var lastWordSeen: (() -> Void)?

    init(store: Store, walletManager: WalletManager, pin: String, callback: @escaping () -> Void) {
        self.store = store
        self.walletManager = walletManager
        self.pin = pin
        self.callback = callback
        super.init(nibName: nil, bundle: nil)
    }

    private let callback: () -> Void

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        view.backgroundColor = .white
        
        label.text = S.WritePaperPhrase.instruction
        label.textAlignment = .center
        label.textColor = .white

        stepLabel.text = String(format: S.WritePaperPhrase.step, 1, phraseViews.count)
        stepLabel.textAlignment = .center
        stepLabel.textColor = UIColor(white: 170.0/255.0, alpha: 1.0)

        addSubviews()
        addConstraints()
        addButtonTargets()

        NotificationCenter.default.addObserver(forName: .UIApplicationWillResignActive, object: nil, queue: nil) { [weak self] note in
            self?.dismiss(animated: true, completion: nil)
        }

        let faqButton = UIButton.buildFaqButton(store: store, articleId: ArticleIds.writePhrase)
        faqButton.tintColor = .white
        navigationItem.rightBarButtonItems = [UIBarButtonItem.negativePadding, UIBarButtonItem(customView: faqButton)]
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    private func addSubviews() {
        view.addSubview(header)
        header.addSubview(label)
        view.addSubview(stepLabel)
        view.addSubview(proceed)
        view.addSubview(previous)
        phraseViews.forEach { view.addSubview($0) }
    }

    private func addConstraints() {

        header.constrainTopCorners(sidePadding: 0, topPadding: 0)
        header.constrain([
            header.constraint(.height, constant: 152.0) ])
        label.constrainBottomCorners(sidePadding: C.padding[3], bottomPadding: C.padding[2])

        phraseViews.enumerated().forEach { index, phraseView in
            //The first phrase should initially be on the screen
            let constant = index == 0 ? 0.0 : phraseOffscreenOffset
            let xConstraint = NSLayoutConstraint(item: phraseView, attribute: .centerX, relatedBy: .equal, toItem: view, attribute: .centerX, multiplier: 1.0, constant: constant)
            phraseView.xConstraint = xConstraint
            phraseView.constrain([
                    phraseView.constraint(.width, constant: PhraseView.defaultSize.width),
                    phraseView.constraint(.height, constant: PhraseView.defaultSize.height),
                    phraseView.constraint(.centerY, toView: view, constant: 0.0),
                    xConstraint
                ])
        }

        stepLabel.constrain([
                NSLayoutConstraint(item: stepLabel, attribute: .top, relatedBy: .equal, toItem: view, attribute: .centerY, multiplier: 1.0, constant: PhraseView.defaultSize.height/2.0 + C.padding[1]),
                stepLabel.constraint(.centerX, toView: view, constant: 0.0),
                stepLabel.constraint(.width, constant: 200.0) //The transitions are smoother if this view is forced to be wider than it needs to be
            ])

        proceedWidth = proceed.constraint(.width, toView: view, constant: -C.padding[2]*2)
        proceed.constrain([
                proceed.constraint(.trailing, toView: view, constant: -C.padding[2]),
                proceed.constraint(.height, constant: C.Sizes.buttonHeight),
                proceed.constraint(.bottom, toView: view, constant: -(C.padding[4] + C.Sizes.buttonHeight)),
                proceedWidth!
            ])

        previousWidth = previous.constraint(.width, toView: view, constant: -view.bounds.width)
        previous.constrain([
                previous.constraint(.leading, toView: view, constant: C.padding[2]),
                previous.constraint(.height, constant: C.Sizes.buttonHeight),
                previous.constraint(.bottom, toView: view, constant: -(C.padding[4] + C.Sizes.buttonHeight)    ),
                previousWidth!
            ])
    }

    private func addButtonTargets() {
        proceed.addTarget(self, action: #selector(proceedTapped), for: .touchUpInside)
        previous.addTarget(self, action: #selector(previousTapped), for: .touchUpInside)
    }

    @objc private func proceedTapped() {
        guard currentPhraseIndex < phraseViews.count - 1 else { callback(); return }
        if currentPhraseIndex == 0 {
            showBothButtons()
        }
        transitionTo(isNext: true)
    }

    @objc private func previousTapped() {
        guard currentPhraseIndex > 0 else { return }
        if currentPhraseIndex == 1 {
            showOneButton()
        }
        transitionTo(isNext: false)
    }

    private func transitionTo(isNext: Bool) {
        let viewToHide = phraseViews[currentPhraseIndex]
        let viewToShow = phraseViews[isNext ? currentPhraseIndex + 1 : currentPhraseIndex - 1]
        if isNext {
            currentPhraseIndex += 1
        } else {
            currentPhraseIndex -= 1
        }

        UIView.spring(0.6, animations: {
            viewToHide.xConstraint?.constant = isNext ? -self.phraseOffscreenOffset : self.phraseOffscreenOffset
            viewToShow.xConstraint?.constant = 0
            self.view.layoutIfNeeded()
        }, completion: { _ in })
    }

    private func showBothButtons() {
        UIView.animate(withDuration: 0.4) {
            self.proceedWidth?.constant = -self.view.bounds.width/2.0 - C.padding[2] - C.padding[1]/2.0
            self.previousWidth?.constant = -self.view.bounds.width/2.0 - C.padding[2] - C.padding[1]/2.0
            self.view.layoutIfNeeded()
        }
    }

    private func showOneButton() {
        UIView.animate(withDuration: 0.4) {
            self.proceedWidth?.constant = -C.padding[2]*2
            self.previousWidth?.constant = -self.view.bounds.width
            self.view.layoutIfNeeded()
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
