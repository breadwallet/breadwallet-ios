//
//  CI.swift
//  loafwallet
//
//  Created by Kerry Washington on 12/30/19.
//  Copyright © 2019 Litecoin Foundation. All rights reserved.
//

import Foundation

struct CI {
    static var mixpanelProdToken:    String = "$(MXP_PROD_ENV)"
    static var mixpanelDevToken:     String = "$(MXP_DEV_ENV)"
    static var shouldRunFirebase = false

}
