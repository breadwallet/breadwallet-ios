//
//  AccountFooterView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-16.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class AccountFooterView: UIView {
    override init (frame : CGRect) {
        super.init(frame : frame)
        setupSubViews()
    }

    convenience init () {
        self.init(frame:CGRect.zero)
    }

    func setupSubViews(){
        let blurEffect = UIBlurEffect(style: .extraLight)
        let effectView = UIVisualEffectView(effect: blurEffect)
        addSubview(effectView)
        effectView.constrain(toSuperviewEdges: nil)

        let send = UIButton(type: .system)
        send.setImage(#imageLiteral(resourceName: "SendButtonIcon"), for: .normal)
        let receive = UIButton(type: .system)
        receive.setImage(#imageLiteral(resourceName: "ReceiveButtonIcon"), for: .normal)
        let menu = UIButton(type: .system)
        menu.setImage(#imageLiteral(resourceName: "MenuButtonIcon"), for: .normal)

        addSubview(send)
        addSubview(receive)
        addSubview(menu)

        send.constrain([
                send.constraint(.leading, toView: self, constant: 0.0),
                send.constraint(.top, toView: self, constant: 0.0),
                send.constraint(.bottom, toView: self, constant: 0.0),
                NSLayoutConstraint(item: send, attribute: .width, relatedBy: .equal, toItem: self, attribute: .width, multiplier: 1.0/3.0, constant: 0.0)
            ])
        receive.constrain([
                NSLayoutConstraint(item: receive, attribute: .leading, relatedBy: .equal, toItem: send, attribute: .trailing, multiplier: 1.0, constant: 0.0),
                receive.constraint(.top, toView: self, constant: 0.0),
                receive.constraint(.bottom, toView: self, constant: 0.0),
                NSLayoutConstraint(item: receive, attribute: .width, relatedBy: .equal, toItem: self, attribute: .width, multiplier: 1.0/3.0, constant: 1.0)
            ])
        menu.constrain([
                NSLayoutConstraint(item: menu, attribute: .leading, relatedBy: .equal, toItem: receive, attribute: .trailing, multiplier: 1.0, constant: 1.0),
                menu.constraint(.top, toView: self, constant: 0.0),
                menu.constraint(.bottom, toView: self, constant: 0.0),
                NSLayoutConstraint(item: menu, attribute: .width, relatedBy: .equal, toItem: self, attribute: .width, multiplier: 1.0/3.0, constant: 1.0)
            ])
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("This class does not support NSCoding")
    }
}
