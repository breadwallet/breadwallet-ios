//
//  EnterPhraseCollectionViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-02-23.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import UIKit

private let itemHeight: CGFloat = 32

class EnterPhraseCollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {

    // MARK: - Public
    var didFinishPhraseEntry: ((String) -> Void)?
    var height: CGFloat {
        return (itemHeight * 4.0) + (2 * sectionInsets) + (3 * interItemSpacing)
    }

    init(keyMaster: KeyMaster) {
        self.keyMaster = keyMaster
        super.init(collectionViewLayout: UICollectionViewFlowLayout())
    }
    
    private let cellHeight: CGFloat = 32
    
    var interItemSpacing: CGFloat {
        return E.isSmallScreen ? 6 : C.padding[1]
    }
    
    var sectionInsets: CGFloat {
        return E.isSmallScreen ? 0 : C.padding[2]
    }
    
    private lazy var cellSize: CGSize = {
        let margins = sectionInsets * 2            // left and right section insets
        let spacing = interItemSpacing * 2
        let widthAvailableForCells = collectionView.frame.width - margins - spacing
        let cellsPerRow: CGFloat = 3
        return CGSize(width: widthAvailableForCells / cellsPerRow, height: cellHeight)
    }()
    
    // MARK: - Private
    private let cellIdentifier = "CellIdentifier"
    private let keyMaster: KeyMaster
    private var phrase: String {
        return (0...11).map { index in
                guard let phraseCell = collectionView?.cellForItem(at: IndexPath(item: index, section: 0)) as? EnterPhraseCell else { return ""}
                return phraseCell.textField.text?.lowercased() ?? ""
            }.joined(separator: " ")
    }
    
    override func viewDidLoad() {
        collectionView = NonScrollingCollectionView(frame: view.bounds, collectionViewLayout: collectionViewLayout)
        collectionView.backgroundColor = Theme.primaryBackground
        collectionView?.register(EnterPhraseCell.self, forCellWithReuseIdentifier: cellIdentifier)
        collectionView?.delegate = self
        collectionView?.dataSource = self
        
        // Omit the rounded border on small screens due to space constraints.
        if !E.isSmallScreen {
            collectionView.layer.cornerRadius = 8.0
            collectionView.layer.borderColor = Theme.secondaryBackground.cgColor
            collectionView.layer.borderWidth = 2.0
        }
        
        collectionView?.isScrollEnabled = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder(atIndex: 0)
    }

    // MARK: - UICollectionViewDataSource
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 12
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return cellSize
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
            return myself.keyMaster.isSeedWordValid(word.lowercased())
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

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        let insets = sectionInsets
        return UIEdgeInsets(top: insets, left: insets, bottom: insets, right: insets)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return interItemSpacing
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return interItemSpacing
    }
    
    // MARK: - Extras
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
