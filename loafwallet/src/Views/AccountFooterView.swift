//
//  AccountFooterView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-16.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class AccountFooterView: UIView {

    var sendCallback: (() -> Void)?
    var receiveCallback: (() -> Void)?
    var menuCallback: (() -> Void)?
    var buyCallback: (() -> Void)?
 
    var hasSetup = false

    init() {
        super.init(frame: .zero)
    }

    override func layoutSubviews() {
        guard !hasSetup else { return }
        DispatchQueue.main.async {
            self.setupSubViews()
        }
        hasSetup = true
    }

    func setupSubViews(){
        
        let backgroundView = UITabBar()
        addSubview(backgroundView)
        backgroundView.constrain(toSuperviewEdges: nil)

        let send = UIButton.vertical(title: S.Button.send.uppercased(), image: #imageLiteral(resourceName: "SendButtonIcon"))
        if #available(iOS 11.0, *) {
            backgroundView.barTintColor = UIColor(named: "lfBackgroundColor")
            send.tintColor = UIColor(named: "headerTextColor")
        } else {
            send.tintColor = .grayTextTint
        }
        send.addTarget(self, action: #selector(AccountFooterView.send), for: .touchUpInside)

        let receive = UIButton.vertical(title: S.Button.receive.uppercased(), image: #imageLiteral(resourceName: "ReceiveButtonIcon"))
        if #available(iOS 11.0, *) {
            receive.tintColor = UIColor(named: "headerTextColor")
        } else {
            receive.tintColor = .grayTextTint
        }
        receive.addTarget(self, action: #selector(AccountFooterView.receive), for: .touchUpInside)
      
        let buy = UIButton.vertical(title: S.Button.buy.uppercased(), image: #imageLiteral(resourceName: "BuyIcon"))
        if #available(iOS 11.0, *) {
            buy.tintColor = UIColor(named: "headerTextColor")
        } else {
            buy.tintColor = .grayTextTint
        }
        buy.addTarget(self, action: #selector(AccountFooterView.buy), for: .touchUpInside)
      
        let menu = UIButton.vertical(title: S.Button.menu.uppercased(), image: #imageLiteral(resourceName: "MenuButtonIcon"))
        if #available(iOS 11.0, *) {
            menu.tintColor = UIColor(named: "headerTextColor")
        } else {
            menu.tintColor = .grayTextTint
        }
        menu.addTarget(self, action: #selector(AccountFooterView.menu), for: .touchUpInside)

        if E.isScreenshots {
            menu.accessibilityLabel = "MENU"
        }

        addSubview(send)
        addSubview(receive)
        addSubview(buy)
        addSubview(menu)
        
        send.isEnabled = checkPaperKeyStatus()
        receive.isEnabled = checkPaperKeyStatus()
        buy.isEnabled = checkPaperKeyStatus()

        send.constrain([
                send.constraint(.leading, toView: self, constant: 0.0),
                send.constraint(.top, toView: self, constant: C.padding[2]),
                NSLayoutConstraint(item: send, attribute: .width, relatedBy: .equal, toItem: self, attribute: .width, multiplier: 1.0/4.0, constant: 0.0)
            ])
        receive.constrain([
                NSLayoutConstraint(item: receive, attribute: .leading, relatedBy: .equal, toItem: send, attribute: .trailing, multiplier: 1.0, constant: 0.0),
                receive.constraint(.top, toView: self, constant: C.padding[2]),
                NSLayoutConstraint(item: receive, attribute: .width, relatedBy: .equal, toItem: self, attribute: .width, multiplier: 1.0/4.0, constant: 1.0)
            ])
        buy.constrain([
          NSLayoutConstraint(item: buy, attribute: .leading, relatedBy: .equal, toItem: receive, attribute: .trailing, multiplier: 1.0, constant: 1.0),
          buy.constraint(.top, toView: self, constant: C.padding[2]),
          NSLayoutConstraint(item: buy, attribute: .width, relatedBy: .equal, toItem: self, attribute: .width, multiplier: 1.0/4.0, constant: 1.0)
          ])
        menu.constrain([
                NSLayoutConstraint(item: menu, attribute: .leading, relatedBy: .equal, toItem: buy, attribute: .trailing, multiplier: 1.0, constant: 1.0),
                menu.constraint(.top, toView: self, constant: C.padding[2]),
                NSLayoutConstraint(item: menu, attribute: .width, relatedBy: .equal, toItem: self, attribute: .width, multiplier: 1.0/4.0, constant: 1.0)
            ])
    }
    
    func checkPaperKeyStatus() -> Bool {
        if UserDefaults.writePaperPhraseDate != nil {
            return true
        } else {
            return false
        }
    }
    
    func refreshButtonStatus() {
        DispatchQueue.main.async {
            self.setupSubViews()
        }
    }

    @objc private func send() { sendCallback?() }
    @objc private func receive() { receiveCallback?() }
    @objc private func buy() { buyCallback?() }
    @objc private func menu() { menuCallback?() }

    required init(coder aDecoder: NSCoder) {
        fatalError("This class does not support NSCoding")
    }
}
