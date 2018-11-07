//
//  EnterPhraseCollectionViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-02-23.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

private let itemHeight: CGFloat = 50.0

class EnterPhraseCollectionViewController : UICollectionViewController {

    //MARK: - Public
    var didFinishPhraseEntry: ((String) -> Void)?
    var height: CGFloat {
        return itemHeight * 4.0
    }

    init(walletManager: BTCWalletManager) {
        self.walletManager = walletManager
        let layout = UICollectionViewFlowLayout()
        let screenWidth = UIScreen.main.safeWidth
        layout.itemSize = CGSize(width: (screenWidth - C.padding[4])/3.0, height: itemHeight)
        layout.minimumLineSpacing = 0.0
        layout.minimumInteritemSpacing = 0.0
        layout.sectionInset = .zero
        super.init(collectionViewLayout: layout)
    }

    //MARK: - Private
    private let cellIdentifier = "CellIdentifier"
    private let walletManager: BTCWalletManager
    private var phrase: String {
        return (0...11).map { index in
                guard let phraseCell = collectionView?.cellForItem(at: IndexPath(item: index, section: 0)) as? EnterPhraseCell else { return ""}
                return phraseCell.textField.text ?? ""
            }.joined(separator: " ")
    }

    override func viewDidLoad() {
        collectionView = NonScrollingCollectionView(frame: view.bounds, collectionViewLayout: collectionViewLayout)
        collectionView?.backgroundColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.1)
        collectionView?.register(EnterPhraseCell.self, forCellWithReuseIdentifier: cellIdentifier)
        collectionView?.delegate = self
        collectionView?.dataSource = self
        collectionView?.layer.cornerRadius = 8.0
        collectionView?.isScrollEnabled = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder(atIndex: 0)
    }

    //MARK: - UICollectionViewDataSource
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 12
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        let item = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath)
        guard let enterPhraseCell = item as? EnterPhraseCell else { return item }
        enterPhraseCell.index = indexPath.row
        enterPhraseCell.didTapNext = { [weak self] in
            self?.becomeFirstResponder(atIndex: indexPath.row + 1)
        }
        enterPhraseCell.didTapPrevious = { [weak self] in
            self?.becomeFirstResponder(atIndex: indexPath.row - 1)
        }
        enterPhraseCell.didTapDone = { [weak self] in
            guard let phrase = self?.phrase else { return }
            self?.didFinishPhraseEntry?(phrase)
        }
        enterPhraseCell.isWordValid = { [weak self] word in
            guard let myself = self else { return false }
            return myself.walletManager.isWordValid(word)
        }
        enterPhraseCell.didEnterSpace = {
            enterPhraseCell.didTapNext?()
        }
        enterPhraseCell.didPasteWords = { [weak self] words in
            guard E.isDebug || E.isTestFlight else { return false }
            guard enterPhraseCell.index == 0, words.count <= 12, let `self` = self else { return false }
            for (index, word) in words.enumerated() {
                self.setText(word, atIndex: index)
            }
            return true
        }

        if indexPath.item == 0 {
            enterPhraseCell.disablePreviousButton()
        } else if indexPath.item == 11 {
            enterPhraseCell.disableNextButton()
        }
        return item
    }

    //MARK: - Extras
    private func becomeFirstResponder(atIndex: Int) {
        guard let phraseCell = collectionView?.cellForItem(at: IndexPath(item: atIndex, section: 0)) as? EnterPhraseCell else { return }
        phraseCell.textField.becomeFirstResponder()
    }

    private func setText(_ text: String, atIndex: Int) {
        guard let phraseCell = collectionView?.cellForItem(at: IndexPath(item: atIndex, section: 0)) as? EnterPhraseCell else { return }
        phraseCell.textField.text = text
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
