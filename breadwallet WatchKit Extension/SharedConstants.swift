//
//  SharedConstants.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-04-27.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

let AW_SESSION_RESPONSE_KEY = "AW_SESSION_RESPONSE_KEY"
let AW_SESSION_REQUEST_TYPE = "AW_SESSION_REQUEST_TYPE"
let AW_SESSION_QR_CODE_BITS_KEY = "AW_QR_CODE_BITS_KEY"

let AW_SESSION_REQUEST_DATA_TYPE_KEY = "AW_SESSION_REQUEST_DATA_TYPE_KEY"

let AW_APPLICATION_CONTEXT_KEY = "AW_APPLICATION_CONTEXT_KEY"
let AW_QR_CODE_BITS_KEY = "AW_QR_CODE_BITS_KEY"

let AW_PHONE_NOTIFICATION_KEY = "AW_PHONE_NOTIFICATION_KEY"
let AW_PHONE_NOTIFICATION_TYPE_KEY = "AW_PHONE_NOTIFICATION_TYPE_KEY"

enum AWSessionRequestDataType : Int {
    case applicationContextData = 0
    case qrCodeBits
}

enum AWSessionRequestType : Int {
    case dataUpdateNotification = 0
    case fetchData
    case qRCodeBits
    case didWipe
}
