//
//  TransactionDetailsViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-02-09.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class TransactionDetailsViewController : UICollectionViewController {

    //MARK: - Public
    init(store: Store, transactions: [Transaction], selectedIndex: Int) {
        self.store = store
        self.transactions = transactions
        self.selectedIndex = selectedIndex
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - C.padding[1])
        layout.sectionInset = UIEdgeInsetsMake(C.padding[1], 0, 0, 0)
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0.0
        super.init(collectionViewLayout: layout)
    }

    //MARK: - Private
    fileprivate let store: Store
    fileprivate let transactions: [Transaction]
    fileprivate let selectedIndex: Int
    fileprivate let cellIdentifier = "CellIdentifier"

    override func viewDidLoad() {
        collectionView?.register(UICollectionViewCell.self, forCellWithReuseIdentifier: cellIdentifier)
        collectionView?.delegate = self
        collectionView?.dataSource = self
        collectionView?.backgroundColor = .clear
        collectionView?.isPagingEnabled = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

//MARK: - UICollectionViewDataSource
extension TransactionDetailsViewController {
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return transactions.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let item = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath)
        item.backgroundColor = .clear
        let view = TransactionDetailView()
        view.transaction = transactions[indexPath.row]
        view.closeCallback = { [weak self] in
            if let delegate = self?.transitioningDelegate as? ModalTransitionDelegate {
                delegate.reset()
            }
            self?.dismiss(animated: true, completion: nil)
        }
        item.addSubview(view)
        view.constrain(toSuperviewEdges: UIEdgeInsetsMake(C.padding[2], C.padding[2], 0.0, -C.padding[2]))
        return item
    }
}

//MARK: - UICollectionViewDelegate
extension TransactionDetailsViewController {

}
