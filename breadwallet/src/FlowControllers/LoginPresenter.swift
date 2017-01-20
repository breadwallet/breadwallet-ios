//
//  LoginPresenter.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-20.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class LoginPresenter : Subscriber {

    //MARK: - Public
    init(store: Store) {
        self.store = store
    }

    //MARK: - Private
    let store: Store
}
