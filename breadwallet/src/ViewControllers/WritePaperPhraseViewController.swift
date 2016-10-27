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
    private let words = ["belong", "mountains", "liverish", "resin", "camion", "negus", "turn", "mandarin", "stumpy", "acerb", "pinworm", "hopeful"]
    private let label = UILabel.makeWrappingLabel(font: UIFont.preferredFont(forTextStyle: .body))
    private lazy var phraseViews: [PhraseView] = {
        return self.words.map { PhraseView(phrase: $0) }
    }()
    private let proceed = UIButton.makeOutlineButton(title: "Next")
    private let previous = UIButton.makeOutlineButton(title: "Previous")
    private var proceedWidth: NSLayoutConstraint?
    private var previousWidth: NSLayoutConstraint?

    private var phraseOffscreenOffset: CGFloat {
        return view.bounds.width/2.0 + PhraseView.defaultSize.width/2.0
    }
    private var count = 0

    init(store: Store) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        view.backgroundColor = .white
        label.text = "Write down each word on a piece of paper and store it in a safe place."
        addSubviews()
        addConstraints()
        addButtonTargets()
    }

    private func addSubviews() {
        view.addSubview(label)
        view.addSubview(proceed)
        view.addSubview(previous)
        phraseViews.forEach { view.addSubview($0) }
    }

    private func addConstraints() {
        label.constrainTopCorners(sidePadding: Constants.Padding.triple, topPadding: Constants.Padding.quad, topLayoutGuide: topLayoutGuide)

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

        proceedWidth = proceed.constraint(.width, toView: view, constant: -Constants.Padding.double*2)
        proceed.constrain([
                proceed.constraint(.trailing, toView: view, constant: -Constants.Padding.double),
                proceed.constraint(.height, constant: Constants.Sizes.buttonHeight),
                proceed.constraint(.bottom, toView: view, constant: -Constants.Padding.quad),
                proceedWidth!
            ])

        previousWidth = previous.constraint(.width, toView: view, constant: -view.bounds.width)
        previous.constrain([
                previous.constraint(.leading, toView: view, constant: Constants.Padding.double),
                previous.constraint(.height, constant: Constants.Sizes.buttonHeight),
                previous.constraint(.bottom, toView: view, constant: -Constants.Padding.quad),
                previousWidth!
            ])

    }

    private func addButtonTargets() {
        proceed.addTarget(self, action: #selector(proceedTapped), for: .touchUpInside)
        previous.addTarget(self, action: #selector(previousTapped), for: .touchUpInside)
    }

    @objc private func proceedTapped() {

        guard count < phraseViews.count - 1 else { return }

        let viewToHide = phraseViews[count]
        let viewToShow = phraseViews[count + 1]

        if #available(iOS 10.0, *) {
            let animator = UIViewPropertyAnimator.springAnimation { 
                viewToHide.xConstraint?.constant = -self.phraseOffscreenOffset
                viewToShow.xConstraint?.constant = 0
                self.view.layoutIfNeeded()
            }
            animator.startAnimation()
            animator.addCompletion { _ in

                self.count += 1
            }
        }
        if self.count == 0 {
            UIView.animate(withDuration: 0.4) {
                self.proceedWidth?.constant = -self.view.bounds.width/2.0 - Constants.Padding.double - Constants.Padding.half
                self.previousWidth?.constant = -self.view.bounds.width/2.0 - Constants.Padding.double - Constants.Padding.half
                self.view.layoutIfNeeded()
            }
        }

    }

    @objc private func previousTapped() {
        guard count > 0 else { return }

        let viewToHide = phraseViews[count]
        let viewToShow = phraseViews[count - 1]

        if #available(iOS 10.0, *) {
            let animator = UIViewPropertyAnimator.springAnimation {
                viewToHide.xConstraint?.constant = self.phraseOffscreenOffset
                viewToShow.xConstraint?.constant = 0
                self.view.layoutIfNeeded()
            }
            animator.startAnimation()
            animator.addCompletion { _ in

                self.count -= 1
            }
        }
        if self.count == 1 {
            UIView.animate(withDuration: 0.4) {
                self.proceedWidth?.constant = -Constants.Padding.double*2
                self.previousWidth?.constant = -self.view.bounds.width
                self.view.layoutIfNeeded()
            }
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
