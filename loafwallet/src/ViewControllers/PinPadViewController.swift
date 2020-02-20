//
//  PinPadViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-15.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

enum PinPadColorStyle {
    case white
    case clear
}

enum KeyboardType {
    case decimalPad
    case pinPad
}

let deleteKeyIdentifier = "del"

class PinPadViewController : UICollectionViewController {

    let currencyDecimalSeparator = NumberFormatter().currencyDecimalSeparator ?? "."
    var isAppendingDisabled = false
    var ouputDidUpdate: ((String) -> Void)?
    var didUpdateFrameWidth: ((CGRect) -> Void)?
    
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
        if currentOutput.utf8.count > 0 {
            currentOutput = String(currentOutput[..<currentOutput.index(currentOutput.startIndex, offsetBy: currentOutput.utf8.count - 1)])
        }
    }

    init(style: PinPadColorStyle, keyboardType: KeyboardType, maxDigits: Int) {
        self.style = style
        self.keyboardType = keyboardType
        self.maxDigits = maxDigits
        let layout = UICollectionViewFlowLayout()
        let screenWidth = UIScreen.main.safeWidth

        layout.minimumLineSpacing = 1.0
        layout.minimumInteritemSpacing = 1.0
        layout.sectionInset = .zero

        switch keyboardType {
        case .decimalPad:
            items = ["1", "2", "3", "4", "5", "6", "7", "8", "9", currencyDecimalSeparator, "0", deleteKeyIdentifier]
            layout.itemSize = CGSize(width: screenWidth/3.0 - 2.0/3.0, height: 48.0 - 1.0)
        case .pinPad:
            items = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", deleteKeyIdentifier]
            layout.itemSize = CGSize(width: screenWidth/3.0 - 2.0/3.0, height: 54.0 - 0.5)
        }

        super.init(collectionViewLayout: layout)
    }

    private let cellIdentifier = "CellIdentifier"
    private let style: PinPadColorStyle
    private let keyboardType: KeyboardType
    private let items: [String]
    private let maxDigits: Int

    override func viewDidLoad() {
        switch style {
        case .white:
            switch keyboardType {
            case .decimalPad:
                collectionView?.backgroundColor = .clear
                collectionView?.register(WhiteDecimalPad.self, forCellWithReuseIdentifier: cellIdentifier)
            case .pinPad:
                collectionView?.backgroundColor = .clear
                collectionView?.register(WhiteNumberPad.self, forCellWithReuseIdentifier: cellIdentifier)
            }
        case .clear:
            switch keyboardType {
            case .decimalPad:
                collectionView?.backgroundColor = .clear
                collectionView?.register(ClearDecimalPad.self, forCellWithReuseIdentifier: cellIdentifier)
            case .pinPad:
                collectionView?.backgroundColor = .clear
                collectionView?.register(ClearNumberPad.self, forCellWithReuseIdentifier: cellIdentifier)
            }
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
        guard let pinPadCell = item as? GenericPinPadCell else { return item }
        pinPadCell.text = items[indexPath.item]
        
        //produces a frame for lining up other subviews
        if indexPath.item == 0 {
             didUpdateFrameWidth?(collectionView.convert(pinPadCell.frame, to: self.view))
        }
        return pinPadCell
    }

    //MARK: - UICollectionViewDelegate
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = items[indexPath.row]
        if item == "del" {
            if currentOutput.count > 0 {
                if currentOutput == ("0" + currencyDecimalSeparator) {
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
                if currentOutput.count == 0 {
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



class GenericPinPadCell : UICollectionViewCell {

    var text: String? {
        didSet {
            if text == deleteKeyIdentifier {
                imageView.image = #imageLiteral(resourceName: "Delete")
                topLabel.text = ""
                centerLabel.text = ""
            } else {
                imageView.image = nil
                topLabel.text = text
                centerLabel.text = text
            }
            setAppearance()
            setSublabel()
        }
    }

    let sublabels = [
        "2": "ABC",
        "3": "DEF",
        "4": "GHI",
        "5": "JKL",
        "6": "MNO",
        "7": "PORS",
        "8": "TUV",
        "9": "WXYZ"
    ]

    override var isHighlighted: Bool {
        didSet {
            guard text != "" else { return } //We don't want the blank cell to highlight
            setAppearance()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    internal let topLabel = UILabel(font: .customBody(size: 28.0))
    internal let centerLabel = UILabel(font: .customBody(size: 28.0))
    internal let sublabel = UILabel(font: .customBody(size: 11.0))
    internal let imageView = UIImageView()

    private func setup() {
        setAppearance()
        topLabel.textAlignment = .center
        centerLabel.textAlignment = .center
        sublabel.textAlignment = .center
        addSubview(topLabel)
        addSubview(centerLabel)
        addSubview(sublabel)
        addSubview(imageView)
        imageView.contentMode = .center
        addConstraints()
    }

    func addConstraints() {
        imageView.constrain(toSuperviewEdges: nil)
        centerLabel.constrain(toSuperviewEdges: nil)
        topLabel.constrain([
            topLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            topLabel.topAnchor.constraint(equalTo: topAnchor, constant: 2.5) ])
        sublabel.constrain([
            sublabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            sublabel.topAnchor.constraint(equalTo: topLabel.bottomAnchor, constant: -3.0) ])
    }

    override var isAccessibilityElement: Bool {
        get {
            return true
        }
        set { }
    }

    override var accessibilityLabel: String? {
        get {
            return topLabel.text
        }
        set { }
    }

    override var accessibilityTraits: UIAccessibilityTraits {
        get {
            return UIAccessibilityTraitStaticText
        }
        set { }
    }

    func setAppearance() {}
    func setSublabel() {}

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


class ClearNumberPad : GenericPinPadCell {

    override func setAppearance() {

        if text == "0" {
            topLabel.isHidden = true
            centerLabel.isHidden = false
        } else {
            topLabel.isHidden = false
            centerLabel.isHidden = true
        }

        topLabel.textColor = .white
        centerLabel.textColor = .white
        sublabel.textColor = .white

        if isHighlighted {
            backgroundColor = .transparentBlack
        } else {
            if text == "" || text == deleteKeyIdentifier {
                backgroundColor = .clear
                imageView.image = imageView.image?.withRenderingMode(.alwaysTemplate)
                imageView.tintColor = .white
            } else {
                backgroundColor = .clear
            }
        }
    }

    override func setSublabel() {
        guard let text = self.text else { return }
        if sublabels[text] != nil {
            sublabel.text = sublabels[text]
        }
    }
}

class ClearDecimalPad : GenericPinPadCell {

    override func setAppearance() {

        centerLabel.backgroundColor = .clear
        imageView.image = imageView.image?.withRenderingMode(.alwaysTemplate)

        if isHighlighted {
            centerLabel.textColor = .grayTextTint
            imageView.tintColor = .grayTextTint
        } else {
            centerLabel.textColor = .white
            imageView.tintColor = .white
        }
    }

    override func addConstraints() {
        centerLabel.constrain(toSuperviewEdges: nil)
        imageView.constrain(toSuperviewEdges: nil)
    }
}

class WhiteDecimalPad : GenericPinPadCell {

    override func setAppearance() {
        if isHighlighted {
            centerLabel.backgroundColor = .secondaryShadow
            centerLabel.textColor = .darkText
        } else {
            centerLabel.backgroundColor = .white
            centerLabel.textColor = .grayTextTint
        }
    }

    override func addConstraints() {
        centerLabel.constrain(toSuperviewEdges: nil)
        imageView.constrain(toSuperviewEdges: nil)
    }
}

class WhiteNumberPad : GenericPinPadCell {

    override func setAppearance() {

        if text == "0" {
            topLabel.isHidden = true
            centerLabel.isHidden = false
        } else {
            topLabel.isHidden = false
            centerLabel.isHidden = true
        }

        if isHighlighted {
            backgroundColor = .secondaryShadow
            topLabel.textColor = .darkText
            centerLabel.textColor = .darkText
            sublabel.textColor = .darkText
        } else {
            if text == "" || text == deleteKeyIdentifier {
                backgroundColor = .whiteTint
                imageView.image = imageView.image?.withRenderingMode(.alwaysTemplate)
                imageView.tintColor = .grayTextTint
            } else {
                backgroundColor = .whiteTint
                topLabel.textColor = .grayTextTint
                centerLabel.textColor = .grayTextTint
                sublabel.textColor = .grayTextTint
            }
        }
    }

    override func setSublabel() {
        guard let text = self.text else { return }
        if sublabels[text] != nil {
            sublabel.text = sublabels[text]
        }
    }
}
