// 
//  GiftViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2020-11-20.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import UIKit

class GiftViewController: UIViewController {
    
    private let gradientView = GradientView()
    private let titleLabel = UILabel(font: Theme.body1, color: .white)
    private let topBorder = UIView(color: .white)
    private let qr = UIImageView(image: UIImage(named: "GiftQR"))
    private let header = UILabel.wrapping(font: Theme.boldTitle, color: .white)
    private let subHeader = UILabel.wrapping(font: Theme.body1, color: UIColor.white.withAlphaComponent(0.85))
    private let amountHeader = UILabel(font: Theme.caption, color: .white)
    
    private let customAmount = BorderedTextInput(placeholder: "Custom amount ($500 max)")
    private let name = BorderedTextInput(placeholder: "Recipient's Name")
    private let bottomBorder = UIView(color: .white)
    private let createButton: UIButton = {
        let button = UIButton.rounded(title: "Create")
        button.tintColor = .white
        button.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        button.layer.cornerRadius = 4
        button.layer.borderWidth = 0.5
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.85).cgColor
        return button
    }()
    private let amounts = [25, 50, 100, 250, 500]
    private let toolbar = UIStackView()
    private var buttons = [UIButton]()
    private var selectedIndex: Int = -1
    
    private let extraSwitch = UISwitch()
    private let extraLabel = UILabel.wrapping(font: Theme.caption, color: .white)
    
    override func viewDidLoad() {
        addSubviews()
        setupConstraints()
        setInitialData()
    }
    
    private func addSubviews() {
        view.addSubview(gradientView)
        view.addSubview(titleLabel)
        view.addSubview(topBorder)
        view.addSubview(qr)
        view.addSubview(header)
        view.addSubview(subHeader)
        view.addSubview(amountHeader)
        view.addSubview(toolbar)
        view.addSubview(customAmount)
        view.addSubview(name)
        view.addSubview(extraSwitch)
        view.addSubview(extraLabel)
        view.addSubview(bottomBorder)
        view.addSubview(createButton)
        addButtons()
    }
    
    private func setupConstraints() {
        gradientView.constrain(toSuperviewEdges: nil)
        titleLabel.constrain([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: C.padding[4]),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor) ])
        topBorder.constrain([
            topBorder.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBorder.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: C.padding[1]),
            topBorder.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBorder.heightAnchor.constraint(equalToConstant: 1.0)])
        qr.constrain([
            qr.topAnchor.constraint(equalTo: topBorder.bottomAnchor, constant: C.padding[4]),
            qr.centerXAnchor.constraint(equalTo: view.centerXAnchor)])
        header.constrain([
            header.topAnchor.constraint(equalTo: qr.bottomAnchor, constant: C.padding[2]),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[6]),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[6])])
        subHeader.constrain([
            subHeader.topAnchor.constraint(equalTo: header.bottomAnchor, constant: C.padding[2]),
            subHeader.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            subHeader.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2])])
        amountHeader.constrain([
            amountHeader.topAnchor.constraint(equalTo: subHeader.bottomAnchor, constant: C.padding[2]),
            amountHeader.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            amountHeader.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2])])
        toolbar.constrain([
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            toolbar.topAnchor.constraint(equalTo: amountHeader.bottomAnchor, constant: C.padding[2]),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]),
            toolbar.heightAnchor.constraint(equalToConstant: 44.0)])
        customAmount.constrain([
            customAmount.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            customAmount.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: C.padding[2]),
            customAmount.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2])])
        name.constrain([
            name.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            name.topAnchor.constraint(equalTo: customAmount.bottomAnchor, constant: C.padding[2]),
            name.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2])])
        
        extraSwitch.constrain([
            extraSwitch.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            extraSwitch.topAnchor.constraint(equalTo: name.bottomAnchor, constant: C.padding[2])
        ])
        
        extraLabel.constrain([
            extraLabel.leadingAnchor.constraint(equalTo: extraSwitch.trailingAnchor, constant: C.padding[1]),
            extraLabel.centerYAnchor.constraint(equalTo: extraSwitch.centerYAnchor),
            extraLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2])
        ])
        
        bottomBorder.constrain([
            bottomBorder.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBorder.topAnchor.constraint(equalTo: extraLabel.bottomAnchor, constant: C.padding[3]),
            bottomBorder.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBorder.heightAnchor.constraint(equalToConstant: 1.0)])
        createButton.constrain([
            createButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            createButton.topAnchor.constraint(equalTo: bottomBorder.bottomAnchor, constant: C.padding[3]),
            createButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]),
            createButton.heightAnchor.constraint(equalToConstant: 44.0)])
    }
    
    private func setInitialData() {
        titleLabel.text = "Give the Gift of Bitcoin"
        header.text = "Send Bitcoin to someone\n even if they don't have a wallet."
        header.textAlignment = .center
        subHeader.text = """
            We'll create what's called a \"paper wallet\" with a QR code and instructions for installing BRD that you can email or text to friends and family
            """
        subHeader.textAlignment = .center
        amountHeader.text = "Choose amount ($USD)"
        toolbar.distribution = .fillEqually
        toolbar.spacing = 8.0
        extraSwitch.onTintColor = .white
        extraLabel.text = "add an additional $10 for import network fees"
        extraLabel.numberOfLines = 0
        extraLabel.lineBreakMode = .byWordWrapping
    }
    
    private func addButtons() {
        let buttons: [UIButton] = amounts.map {
            let button = UIButton.rounded(title: "$ \($0)")
            button.tintColor = .white
            button.backgroundColor = UIColor.white.withAlphaComponent(0.1)
            button.layer.cornerRadius = 4
            button.layer.borderWidth = 0.5
            button.layer.borderColor = UIColor.white.withAlphaComponent(0.85).cgColor
            return button
        }
        for (index, button) in buttons.enumerated() {
            self.toolbar.addArrangedSubview(button)
            button.tap = {
                self.didTap(index: index)
            }
        }
        self.buttons = buttons
    }
    
    private func didTap(index: Int) {
        let selectedButton = buttons[index]
        let previousSelectedButton: UIButton? = selectedIndex >= 0 ? buttons[selectedIndex] : nil
        
        selectedIndex = index
        
        UIView.animate(withDuration: 0.4, animations: {
            selectedButton.backgroundColor = UIColor.white.withAlphaComponent(0.85)
            selectedButton.layer.cornerRadius = 4
            selectedButton.layer.borderWidth = 0.5
            selectedButton.layer.borderColor = UIColor.white.cgColor
            selectedButton.tintColor = UIColor.fromHex("FF7E47")
            
            previousSelectedButton?.backgroundColor = UIColor.white.withAlphaComponent(0.1)
            previousSelectedButton?.layer.cornerRadius = 4
            previousSelectedButton?.layer.borderWidth = 0.5
            previousSelectedButton?.layer.borderColor = UIColor.white.withAlphaComponent(0.85).cgColor
            previousSelectedButton?.tintColor = .white
        })
    }
    
}
