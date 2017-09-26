//
//  AppContainerViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-09-22.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class AppContainerViewController : UIViewController {

    var child: UIViewController?

    override var preferredStatusBarStyle: UIStatusBarStyle {
        guard let vc = child else { return .default }
        return vc.preferredStatusBarStyle
    }
}
