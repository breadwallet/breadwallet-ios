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
        setupSubviewProperties()
        addSubviews()
        addConstraints()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    private func setupSubviewProperties() {
        view.backgroundColor = .white
        header.closeCallback = {
            self.dismiss(animated: true, completion: nil)
        }
        scrollView.alwaysBounceVertical = true
        scrollView.delegate = self
        info.text = S.SecurityCenter.info
        info.numberOfLines = 0
        info.lineBreakMode = .byWordWrapping
    }

    private func addSubviews() {
        view.addSubview(scrollView)
        scrollView.addSubview(headerBackground)
        headerBackground.addSubview(header)
        headerBackground.addSubview(shield)
        scrollView.addSubview(pinCell)
        scrollView.addSubview(touchIdCell)
        scrollView.addSubview(paperKeyCell)
        scrollView.addSubview(info)
    }

    private func addConstraints() {
        scrollView.constrain([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),    scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor) ])
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
        shield.constrain([
            shield.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shield.centerYAnchor.constraint(equalTo: headerBackground.centerYAnchor, constant: C.padding[3]) ])
        info.constrain([
            info.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: C.padding[2]),
            info.topAnchor.constraint(equalTo: headerBackground.bottomAnchor, constant: C.padding[2]),
            info.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -C.padding[4]) ])
        scrollView.addSubview(separator)
        separator.constrain([
            separator.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: C.padding[2]),
            separator.topAnchor.constraint(equalTo: info.bottomAnchor, constant: C.padding[2]),
            separator.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -C.padding[2]),
            separator.heightAnchor.constraint(equalToConstant: 1.0) ])
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

    fileprivate var headerBackgroundHeight: NSLayoutConstraint?
    private let headerBackground = SecurityCenterHeader()
    private let header = ModalHeaderView(title: S.SecurityCenter.title, isFaqHidden: false, style: .light)
    private let shield = UIImageView(image: #imageLiteral(resourceName: "shield"))
    private let scrollView = UIScrollView()
    private let info = UILabel(font: .customBody(size: 16.0))
    private let pinCell = SecurityCenterCell(title: S.SecurityCenter.Cells.pinTitle, descriptionText: S.SecurityCenter.Cells.pinDescription)
    private let touchIdCell = SecurityCenterCell(title: S.SecurityCenter.Cells.touchIdTitle, descriptionText: S.SecurityCenter.Cells.touchIdDescription)
    private let paperKeyCell = SecurityCenterCell(title: S.SecurityCenter.Cells.paperKeyTitle, descriptionText: S.SecurityCenter.Cells.paperKeyDescription)
    private let separator = UIView(color: .secondaryShadow)
}

extension SecurityCenterViewController : UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let yOffset = scrollView.contentOffset.y
        headerBackgroundHeight?.constant = headerHeight - yOffset
    }
}
