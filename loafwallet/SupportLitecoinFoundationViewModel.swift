//
//  SupportLitecoinFoundationViewModel.swift
//  loafwallet
//
//  Created by Kerry Washington on 11/9/20.
//  Copyright © 2020 Litecoin Foundation. All rights reserved.
//

import Foundation
import SwiftUI
import Combine


class SupportLitecoinFoundationViewModel: ObservableObject {
    
    //MARK: - Combine Variables
    @Published
    var supportLTCAddress: String = ""
    
    //MARK: - Public Variables
    var didGetLTCAddress: ((String) -> Void)?
    
    init() {}
    
    func updateAddressString(address: String) {
        didGetLTCAddress?(address)
    }
}
