//
//  PinPadViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-15.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit
import LocalAuthentication

enum PinPadStyle {
    case white
    case clear
}

enum KeyboardType {
    case decimalPad
    case pinPad
}

class PinPadViewController: UICollectionViewController {

    enum SpecialKeys: String {
        case delete = "del"
        case biometrics = "bio"

        func image(forStyle: PinPadStyle) -> UIImage {
            switch self {
            case .delete:
                return forStyle == .clear ? #imageLiteral(resourceName: "CutoutDelete") : #imageLiteral(resourceName: "Delete")
            case .biometrics:
                switch forStyle {
                case .clear:
                    return LAContext.biometricType() == .face ? #imageLiteral(resourceName: "CutoutFaceId").withRenderingMode(.alwaysTemplate) : #imageLiteral(resourceName: "TouchIDCutout").withRenderingMode(.alwaysTemplate)
                case .white:
                    return LAContext.biometricType() == .face ? #imageLiteral(resourceName: "FaceId").withRenderingMode(.alwaysTemplate) : #imageLiteral(resourceName: "TouchId").withRenderingMode(.alwaysTemplate)
                }
                
            }
        }
    }

    let currencyDecimalSeparator = NumberFormatter().currencyDecimalSeparator ?? "."
    var isAppendingDisabled = false
    var ouputDidUpdate: ((String) -> Void)?
    var didTapBiometrics: (() -> Void)?
    var shouldShowBiometrics: Bool

    var height: CGFloat {
        switch keyboardType {
        case .decimalPad:
            return 48.0*4.0
        case .pinPad:
            return 54.0*4.0
        }
    }

    var currentOutput = ""

    func clear() {
        isAppendingDisabled = false
        currentOutput = ""
    }

    func removeLast() {
        if !currentOutput.utf8.isEmpty {
            currentOutput = String(currentOutput[..<currentOutput.index(currentOutput.startIndex, offsetBy: currentOutput.utf8.count - 1)])
        }
    }

    init(style: PinPadStyle, keyboardType: KeyboardType, maxDigits: Int, shouldShowBiometrics: Bool) {
        self.style = style
        self.keyboardType = keyboardType
        self.maxDigits = maxDigits
        self.shouldShowBiometrics = shouldShowBiometrics
        let layout = UICollectionViewFlowLayout()
        let itemWidth = floor(UIScreen.main.safeWidth/3.0)

        layout.minimumLineSpacing = 1.0
        layout.minimumInteritemSpacing = 1.0
        layout.sectionInset = .zero

        switch keyboardType {
        case .decimalPad:
            items = ["1", "2", "3", "4", "5", "6", "7", "8", "9", currencyDecimalSeparator, "0", SpecialKeys.delete.rawValue]
            layout.itemSize = CGSize(width: itemWidth - 2.0/3.0, height: 48.0 - 1.0)
        case .pinPad:
            if shouldShowBiometrics {
                items = ["1", "2", "3", "4", "5", "6", "7", "8", "9", SpecialKeys.delete.rawValue, "0", SpecialKeys.biometrics.rawValue]
            } else {
                items = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", SpecialKeys.delete.rawValue]
            }
            if style == .clear {
                layout.itemSize = CGSize(width: itemWidth, height: 54.0)
                layout.minimumLineSpacing = 0.0
                layout.minimumInteritemSpacing = 0.0
            } else {
                layout.itemSize = CGSize(width: itemWidth - 2.0/3.0, height: 54.0 - 0.5)
            }
        }

        super.init(collectionViewLayout: layout)
    }

    private let cellIdentifier = "CellIdentifier"
    private let style: PinPadStyle
    private let keyboardType: KeyboardType
    private let items: [String]
    private let maxDigits: Int

    override func viewDidLoad() {
        switch style {
        case .white:
            switch keyboardType {
            case .decimalPad:
                collectionView?.backgroundColor = .white
                collectionView?.register(WhiteDecimalPad.self, forCellWithReuseIdentifier: cellIdentifier)
            case .pinPad:
                collectionView?.backgroundColor = .whiteTint
                collectionView?.register(WhiteNumberPad.self, forCellWithReuseIdentifier: cellIdentifier)
            }
        case .clear:
            collectionView?.backgroundColor = .clear

            if keyboardType == .pinPad {
                collectionView?.register(ClearNumberPad.self, forCellWithReuseIdentifier: cellIdentifier)
            } else {
                assert(false, "Invalid cell")
            }
        }
        collectionView?.delegate = self
        collectionView?.dataSource = self

        //Even though this view will never scroll, this stops a gesture recognizer
        //from listening for scroll events
        //This prevents a delay in cells highlighting right when they are tapped
        collectionView?.isScrollEnabled = false

#if targetEnvironment(simulator)
        // Only invoke the auto-enter PIN for the login case.
        if UserDefaults.debugShouldAutoEnterPIN && Store.state.isLoginRequired {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                for _ in 0...5 {
                    self.handleInputAtItemIndex(index: 0)
                }
            }
        }
#endif
    }
    
    private func handleInputAtItemIndex(index: Int) {
        let item = items[index]
        
        if let specialKey = SpecialKeys(rawValue: item) {
            switch specialKey {
            case .delete:
                if !currentOutput.isEmpty {
                    if currentOutput == ("0" + currencyDecimalSeparator) {
                        currentOutput = ""
                    } else {
                        currentOutput.remove(at: currentOutput.index(before: currentOutput.endIndex))
                    }
                }
            case .biometrics:
                didTapBiometrics?()
            }
        } else {
            if shouldAppendChar(char: item) && !isAppendingDisabled {
                currentOutput += item
            }
        }
        
        ouputDidUpdate?(currentOutput)        
    }

    // MARK: - UICollectionViewDataSource
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let item = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath)
        guard let pinPadCell = item as? GenericPinPadCell else { return item }
        pinPadCell.text = items[indexPath.item]
        return pinPadCell
    }

    // MARK: - UICollectionViewDelegate
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        handleInputAtItemIndex(index: indexPath.item)
    }

    func shouldAppendChar(char: String) -> Bool {
        let decimalLocation = currentOutput.range(of: currencyDecimalSeparator)?.lowerBound

        //Don't allow more that maxDigits decimal points
        if let location = decimalLocation {
            let locationValue = currentOutput.distance(from: currentOutput.endIndex, to: location)
            if locationValue < -maxDigits {
                return false
            }
        }

        //Don't allow more than 2 decimal separators
        if currentOutput.contains("\(currencyDecimalSeparator)") && char == currencyDecimalSeparator {
            return false
        }

        if keyboardType == .decimalPad {
            if currentOutput == "0" {
                //Append . to 0
                if char == currencyDecimalSeparator {
                    return true

                //Dont append 0 to 0
                } else if char == "0" {
                    return false

                //Replace 0 with any other digit
                } else {
                    currentOutput = char
                    return false
                }
            }
        }

        if char == currencyDecimalSeparator {
            if decimalLocation == nil {
                //Prepend a 0 if the first character is a decimal point
                if currentOutput.isEmpty {
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
