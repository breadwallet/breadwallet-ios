// 
//  CurrencyExtensions.swift
//  breadwalletWidgetExtension
//
//  Created by stringcode on 18/02/2021.
//  Copyright © 2021 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import Foundation
import SwiftUI

extension Currency {
    
    var noBgImage: Image {
        image(at: DefaultImageStoreService().noBgFolder().appendingPathComponent(code.lowercased()),
              renderingMode: .alwaysTemplate)
    }
    
    var bgImage: Image {
        image(at: DefaultImageStoreService().bgFolder().appendingPathComponent(code.lowercased()))
    }

    class var placeholderImage: Image {
        Image("placeholder")
    }
    
    func image(at url: URL, renderingMode: UIImage.RenderingMode = .automatic) -> Image {
        guard let image = UIImage(contentsOfFile: url.path) else {
            return Currency.placeholderImage
        }
        return Image(uiImage: image.withRenderingMode(renderingMode))
    }
}
