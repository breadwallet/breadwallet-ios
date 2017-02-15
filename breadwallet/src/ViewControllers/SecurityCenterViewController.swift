//
//  SecurityCenterViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-02-14.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class SecurityCenterHeader : UIView, GradientDrawable {
    override func draw(_ rect: CGRect) {
        drawGradient(rect)
    }
}

private let headerHeight: CGFloat = 222.0

class SecurityCenterViewController : UIViewController {

    override func viewDidLoad() {
        view.backgroundColor = .white
        view.addSubview(scrollView)

        scrollView.addSubview(headerBackground)
        headerBackground.addSubview(header)
        headerBackground.addSubview(shield)

        scrollView.constrain([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor) ])

        headerBackground.constrain([
            headerBackground.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            headerBackground.topAnchor.constraint(equalTo: view.topAnchor),
            headerBackground.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            headerBackground.widthAnchor.constraint(equalTo: view.widthAnchor) ])
        headerBackgroundHeight = headerBackground.heightAnchor.constraint(equalToConstant: headerHeight)
        headerBackground.constrain([headerBackgroundHeight])

        header.constrain([
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.topAnchor.constraint(equalTo: headerBackground.topAnchor, constant: 20.0),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: C.Sizes.headerHeight)])
        header.closeCallback = {
            self.dismiss(animated: true, completion: nil)
        }

        shield.constrain([
            shield.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shield.centerYAnchor.constraint(equalTo: headerBackground.centerYAnchor, constant: C.padding[3]) ])

        scrollView.addSubview(info)
        scrollView.alwaysBounceVertical = true
        scrollView.delegate = self
        info.constrain([
            info.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: C.padding[2]),
            info.topAnchor.constraint(equalTo: headerBackground.bottomAnchor, constant: C.padding[2]),
            info.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -C.padding[4]) ])
        info.text = "Breadwallet provides security features for protecting your money. Click each feature below to learn more."
        info.numberOfLines = 0
        info.lineBreakMode = .byWordWrapping

        let separator = UIView(color: .secondaryShadow)
        scrollView.addSubview(separator)
        separator.constrain([
            separator.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: C.padding[2]),
            separator.topAnchor.constraint(equalTo: info.bottomAnchor, constant: C.padding[2]),
            separator.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -C.padding[2]),
            separator.heightAnchor.constraint(equalToConstant: 1.0) ])

        let pinCell = SecurityCenterCell(title: S.SecurityCenter.Cells.pinTitle, descriptionText: S.SecurityCenter.Cells.pinDescription)
        pinCell.isEnabled = true
        let touchIdCell = SecurityCenterCell(title: S.SecurityCenter.Cells.touchIdTitle, descriptionText: S.SecurityCenter.Cells.touchIdDescription)
        let paperKeyCell = SecurityCenterCell(title: S.SecurityCenter.Cells.paperKeyTitle, descriptionText: S.SecurityCenter.Cells.paperKeyDescription)
        scrollView.addSubview(pinCell)
        scrollView.addSubview(touchIdCell)
        scrollView.addSubview(paperKeyCell)
        pinCell.constrain([
            pinCell.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            pinCell.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: C.padding[2]),
            pinCell.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor) ])
        touchIdCell.constrain([
            touchIdCell.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            touchIdCell.topAnchor.constraint(equalTo: pinCell.bottomAnchor),
            touchIdCell.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor) ])
        paperKeyCell.constrain([
            paperKeyCell.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            paperKeyCell.topAnchor.constraint(equalTo: touchIdCell.bottomAnchor),
            paperKeyCell.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            paperKeyCell.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -C.padding[2]) ])
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    private let headerBackground = SecurityCenterHeader()
    private let header = ModalHeaderView(title: S.SecurityCenter.title, isFaqHidden: false, style: .light)
    fileprivate let shield = UIImageView(image: #imageLiteral(resourceName: "shield"))
    private let scrollView = UIScrollView()
    private let info = UILabel(font: .customBody(size: 16.0))
    fileprivate var headerBackgroundHeight: NSLayoutConstraint?
}

extension SecurityCenterViewController : UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let yOffset = scrollView.contentOffset.y
        headerBackgroundHeight?.constant = headerHeight - yOffset
    }
}
