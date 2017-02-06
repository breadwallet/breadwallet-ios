//
//  PinPadViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-15.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

enum PinPadStyle {
    case white
    case clear
}

enum KeyboardType {
    case decimalPad
    case pinPad
}

let deleteKeyIdentifier = "del"

class PinPadViewController : UICollectionViewController {
    
    var isAppendingDisabled = false
    var ouputDidUpdate: ((String) -> Void)?

    var height: CGFloat {
        switch keyboardType {
        case .decimalPad:
            return 48.0*4.0
        case .pinPad:
            return 54.0*4.0
        }
    }

    func clear() {
        isAppendingDisabled = false
        currentOutput = ""
    }
    init(style: PinPadStyle, keyboardType: KeyboardType) {
        self.style = style
        self.keyboardType = keyboardType
        let layout = UICollectionViewFlowLayout()
        let screenWidth = UIScreen.main.bounds.width

        layout.minimumLineSpacing = 1.0
        layout.minimumInteritemSpacing = 1.0
        layout.sectionInset = .zero

        switch keyboardType {
        case .decimalPad:
            items = ["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0", deleteKeyIdentifier]
            layout.itemSize = CGSize(width: screenWidth/3.0 - 2.0/3.0, height: 48.0 - 1.0)
        case .pinPad:
            items = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", deleteKeyIdentifier]
            layout.itemSize = CGSize(width: screenWidth/3.0 - 2.0/3.0, height: 54.0 - 0.5)
        }

        super.init(collectionViewLayout: layout)
    }

    private let cellIdentifier = "CellIdentifier"
    private let style: PinPadStyle
    private let keyboardType: KeyboardType
    private let items: [String]
    private var currentOutput = ""

    override func viewDidLoad() {
        switch style {
        case .white:
            collectionView?.backgroundColor = .white
            collectionView?.register(WhitePinPadCell.self, forCellWithReuseIdentifier: cellIdentifier)
        case .clear:
            collectionView?.backgroundColor = .clear
            collectionView?.register(ClearPinPadCell.self, forCellWithReuseIdentifier: cellIdentifier)
        }
        collectionView?.delegate = self
        collectionView?.dataSource = self

        //Even though this view will never scroll, this stops a gesture recognizer
        //from listening for scroll events
        //This prevents a delay in cells highlighting right when they are tapped
        collectionView?.isScrollEnabled = false
    }

    //MARK: - UICollectionViewDataSource
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let item = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath)
        guard let pinPadCell = item as? PinPadCell else { return item }
        pinPadCell.text = items[indexPath.item]
        return pinPadCell
    }

    //MARK: - UICollectionViewDelegate
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = items[indexPath.row]
        if item == "del" {
            if currentOutput.characters.count > 0 {
                if currentOutput == "0." {
                    currentOutput = ""
                } else {
                    currentOutput.remove(at: currentOutput.index(before: currentOutput.endIndex))
                }
            }
        } else {
            if shouldAppendChar(char: item) && !isAppendingDisabled {
                currentOutput = currentOutput + item
            }
        }
        ouputDidUpdate?(currentOutput)
    }

    func shouldAppendChar(char: String) -> Bool {
        let numberFormatter = NumberFormatter()
        let decimalLocation = currentOutput.range(of: numberFormatter.currencyDecimalSeparator)?.lowerBound
        if char == numberFormatter.currencyDecimalSeparator {
            if decimalLocation == nil {
                //Prepend a 0 if the first character is a decimal point
                if currentOutput.characters.count == 0 {
                    currentOutput = "0"
                }
                return true
            } else {
                return false
            }
        }
        return true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
