//
//  StartImportViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-06-13.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class StartImportViewController : UIViewController {

    init() {
        super.init(nibName: nil, bundle: nil)
    }
    private let header = RadialGradientView(backgroundColor: .blue, offset: 64.0)
    private let illustration = UIImageView(image: #imageLiteral(resourceName: "ImportIllustration"))
    private let message = UILabel.wrapping(font: .customBody(size: 16.0), color: .darkText)
    private let warning = UILabel.wrapping(font: .customBody(size: 16.0), color: .darkText)
    private let button = ShadowButton(title: S.Import.scan, type: .primary)
    private let bullet = UIImageView(image: #imageLiteral(resourceName: "deletecircle"))
    private let leftCaption = UILabel.wrapping(font: .customMedium(size: 13.0), color: .darkText)
    private let rightCaption = UILabel.wrapping(font: .customMedium(size: 13.0), color: .darkText)

    override func viewDidLoad() {
        addSubviews()
        addConstraints()
        setInitialData()
    }

    private func addSubviews() {
        view.addSubview(header)
        header.addSubview(illustration)
        header.addSubview(leftCaption)
        header.addSubview(rightCaption)
        view.addSubview(message)
        view.addSubview(button)
        view.addSubview(message)
        view.addSubview(bullet)
        view.addSubview(warning)
    }

    private func addConstraints() {
        header.constrainTopCorners(sidePadding: 0, topPadding: 0)
        header.constrain([
            header.constraint(.height, constant: 220.0) ])
        illustration.constrain([
            illustration.constraint(.width, constant: 64.0),
            illustration.constraint(.height, constant: 84.0),
            illustration.constraint(.centerX, toView: header, constant: 0.0),
            illustration.constraint(.centerY, toView: header, constant: -C.padding[1]) ])
        leftCaption.constrain([
            leftCaption.topAnchor.constraint(equalTo: illustration.bottomAnchor, constant: C.padding[1]),
            leftCaption.trailingAnchor.constraint(equalTo: header.centerXAnchor, constant: -C.padding[2]),
            leftCaption.widthAnchor.constraint(equalToConstant: 80.0)])
        rightCaption.constrain([
            rightCaption.topAnchor.constraint(equalTo: illustration.bottomAnchor, constant: C.padding[1]),
            rightCaption.leadingAnchor.constraint(equalTo: header.centerXAnchor, constant: C.padding[2]),
            rightCaption.widthAnchor.constraint(equalToConstant: 80.0)])
        message.constrain([
            message.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            message.topAnchor.constraint(equalTo: header.bottomAnchor, constant: C.padding[2]),
            message.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]) ])
        bullet.constrain([
            bullet.leadingAnchor.constraint(equalTo: message.leadingAnchor),
            bullet.topAnchor.constraint(equalTo: message.bottomAnchor, constant: C.padding[4]),
            bullet.widthAnchor.constraint(equalToConstant: 16.0),
            bullet.heightAnchor.constraint(equalToConstant: 16.0) ])
        warning.constrain([
            warning.leadingAnchor.constraint(equalTo: bullet.trailingAnchor, constant: C.padding[2]),
            warning.topAnchor.constraint(equalTo: bullet.topAnchor, constant: 0.0),
            warning.trailingAnchor.constraint(equalTo: message.trailingAnchor) ])
        button.constrain([
            button.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[3]),
            button.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -C.padding[4]),
            button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[3]),
            button.constraint(.height, constant: C.Sizes.buttonHeight) ])
    }

    private func setInitialData() {
        view.backgroundColor = .white
        illustration.contentMode = .scaleAspectFill
        message.text = S.Import.importMessage
        leftCaption.text = S.Import.leftCaption
        leftCaption.textAlignment = .center
        rightCaption.text = S.Import.rightCaption
        rightCaption.textAlignment = .center
        warning.text = S.Import.importWarning

        button.tap = { [weak self] in
            let scan = ScanViewController(completion: { (request) in
                print("blah")
            }, isValidURI: { (string) -> Bool in
                return true
            })
            self?.parent?.present(scan, animated: true, completion: nil)
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
