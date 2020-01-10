//
//  CI.swift
//  loafwallet
//
//  Created by Kerry Washington on 12/30/19.
//  Copyright © 2019 Litecoin Foundation. All rights reserved.
//

import Foundation

struct CI {
    static var mixpanelTokenProdKey:    String = "$(MXP_PROD_ENV_KEY)"
    static var mixpanelTokenDevKey:     String = "$(MXP_DEV_ENV_KEY)"
    static var newRelicTokenProdKey:    String = "$(NR_PROD_ENV_KEY)"
    static var newRelicTokenDevKey:     String = "$(NR_DEV_ENV_KEY)"
}
