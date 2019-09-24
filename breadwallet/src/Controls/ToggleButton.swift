//
//  ToggleButton.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-06-24.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import UIKit

class ToggleButton: UIButton {
    
    var listType: EditWalletType = .add
    
    init(normalTitle: String, normalColor: UIColor, selectedTitle: String, selectedColor: UIColor) {
        super.init(frame: .zero)
        self.titleLabel?.font = UIFont.customBody(size: 14.0)
        self.setTitle(normalTitle, for: .normal)
        self.setTitle(selectedTitle, for: .selected)
        self.setTitleColor(normalColor, for: .normal)
        self.setTitleColor(selectedColor, for: .selected)
        self.setTitleColor(selectedColor, for: .highlighted)
        self.setTitleColor(normalColor.withAlphaComponent(0.4), for: .disabled)
        self.layer.cornerRadius = 6.0
        self.layer.borderWidth = 1.0
        updateColors()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var isSelected: Bool {
        didSet {
            updateColors()
        }
    }
    
    override var isHighlighted: Bool { 
        didSet {
            updateColors()
        }
    }
    
    private func updateColors() {
        if listType == .manage {
            guard let color = isHighlighted ? titleColor(for: .selected) : titleColor(for: .normal) else { return }
            self.backgroundColor = color.withAlphaComponent(0.1)
            self.layer.borderColor = color.withAlphaComponent(0.5).cgColor
        } else {
            guard let color = isSelected ? titleColor(for: .selected) : titleColor(for: .normal) else { return }
            self.backgroundColor = color.withAlphaComponent(0.1)
            self.layer.borderColor = color.withAlphaComponent(0.5).cgColor
        }
    }
}
