//
//  PinPadViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-15.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

enum PinPadAction {
    case add(char: String)
    case delete
}

private let cellIdentifier = "CellIdentifier"

class PinPadViewController : UICollectionViewController {

    var didPressKey: ((PinPadAction) -> Void)?

    init() {
        let layout = UICollectionViewFlowLayout()
        let screenWidth = UIScreen.main.bounds.width
        layout.itemSize = CGSize(width: screenWidth/3.0, height: 48.0)
        layout.minimumLineSpacing = 0.0
        layout.minimumInteritemSpacing = 0.0
        layout.sectionInset = .zero
        super.init(collectionViewLayout: layout)
    }

    private let items = ["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0", "del"]

    override func viewDidLoad() {
        collectionView?.register(PinPadCell.self, forCellWithReuseIdentifier: cellIdentifier)
        collectionView?.delegate = self
        collectionView?.dataSource = self
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let item = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath)
        guard let pinPadCell = item as? PinPadCell else { return item }
        pinPadCell.text = items[indexPath.item]
        return pinPadCell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = items[indexPath.row]
        if item == "del" {
            didPressKey?(.delete)
        } else {
            didPressKey?(.add(char: item))
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
