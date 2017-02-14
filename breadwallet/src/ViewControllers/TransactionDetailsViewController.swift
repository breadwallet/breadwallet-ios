//
//  TransactionDetailsViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-02-09.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class TransactionDetailsViewController : UICollectionViewController, Subscriber {

    //MARK: - Public
    init(store: Store, transactions: [Transaction], selectedIndex: Int) {
        self.store = store
        self.transactions = transactions
        self.selectedIndex = selectedIndex
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: UIScreen.main.bounds.width-C.padding[4], height: UIScreen.main.bounds.height - C.padding[1])
        layout.sectionInset = UIEdgeInsetsMake(C.padding[1], 0, 0, 0)
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = C.padding[1]
        super.init(collectionViewLayout: layout)
    }

    //MARK: - Private
    fileprivate let store: Store
    fileprivate var transactions: [Transaction]
    fileprivate let selectedIndex: Int
    fileprivate let cellIdentifier = "CellIdentifier"
    fileprivate var currency: Currency = .bitcoin
    fileprivate let secretScrollView = UIScrollView()

    deinit {
        store.unsubscribe(self)
    }

    override func viewDidLoad() {
        collectionView?.register(UICollectionViewCell.self, forCellWithReuseIdentifier: cellIdentifier)
        collectionView?.delegate = self
        collectionView?.dataSource = self
        collectionView?.backgroundColor = .clear
        collectionView?.contentInset = UIEdgeInsetsMake(C.padding[2], C.padding[2], C.padding[2], C.padding[2])
        setupScrolling()
        store.subscribe(self, selector: { $0.currency != $1.currency }, callback: { self.currency = $0.currency })
        store.lazySubscribe(self, selector: { $0.walletState.transactions != $1.walletState.transactions }, callback: {
            self.transactions = $0.walletState.transactions
            self.collectionView?.reloadData()
        })
    }

    private func setupScrolling() {
        view.addSubview(secretScrollView)
        secretScrollView.isPagingEnabled = true
        secretScrollView.frame = CGRect(x: C.padding[2] - 4.0, y: C.padding[1], width: UIScreen.main.bounds.width - C.padding[3], height: UIScreen.main.bounds.height - C.padding[1])
        secretScrollView.showsHorizontalScrollIndicator = false
        secretScrollView.delegate = self
        secretScrollView.alwaysBounceHorizontal = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let contentSize = collectionView?.contentSize else { return }
        secretScrollView.contentSize = contentSize
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        collectionView?.scrollToItem(at: IndexPath(item: selectedIndex, section: 0), at: .centeredHorizontally, animated: false)
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let collectionView = collectionView else { return }
        guard scrollView == secretScrollView else { return }
        var contentOffset = scrollView.contentOffset
        contentOffset.x = contentOffset.x - collectionView.contentInset.left
        contentOffset.y = contentOffset.y - collectionView.contentInset.top
        collectionView.contentOffset = contentOffset
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

        //TODO - make these recycle properly
        let view = TransactionDetailView(currency: currency)
        view.transaction = transactions[indexPath.row]
        view.closeCallback = { [weak self] in
            if let delegate = self?.transitioningDelegate as? ModalTransitionDelegate {
                delegate.reset()
            }
            self?.dismiss(animated: true, completion: nil)
        }
        item.addSubview(view)
        view.constrain(toSuperviewEdges: nil)
        return item
    }
}
