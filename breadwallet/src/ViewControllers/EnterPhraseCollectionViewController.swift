//
//  EnterPhraseCollectionViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-02-23.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class EnterPhraseCollectionViewController : UICollectionViewController {

    init() {
        let layout = UICollectionViewFlowLayout()
        let screenWidth = UIScreen.main.bounds.width
        layout.itemSize = CGSize(width: (screenWidth - C.padding[4])/3.0, height: 30.0)
        layout.minimumLineSpacing = 0.0
        layout.minimumInteritemSpacing = 0.0
        layout.sectionInset = .zero
        super.init(collectionViewLayout: layout)
    }

    private let cellIdentifier = "CellIdentifier"

    override func viewDidLoad() {
        collectionView?.backgroundColor = .white
        collectionView?.register(EnterPhraseCell.self, forCellWithReuseIdentifier: cellIdentifier)
        collectionView?.delegate = self
        collectionView?.dataSource = self
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
        return item
    }

    //MARK: - Extras
    private func becomeFirstResponder(atIndex: Int) {
        guard let phraseCell = collectionView?.cellForItem(at: IndexPath(item: atIndex, section: 0)) as? EnterPhraseCell else { return }
        phraseCell.textField.becomeFirstResponder()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
