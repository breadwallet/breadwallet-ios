//
//  URLController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-05-26.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

class URLController {

    init(store: Store) {
        self.store = store
    }

    func handleUrl(_ url: URL) -> Bool {
        guard url.scheme == "bitcoin" || url.scheme == "bread" else {
            return false
        }


        if url.scheme == "bitcoin" {
            
        }

        return true

    }

    private let store: Store

}
