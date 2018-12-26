//
//  TokenImageNoBackground.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-09-25.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import UIKit

class RenderedIconBase: UIView {
    
    fileprivate let label = UILabel()
    fileprivate let currency: Currency
    fileprivate var didLayout = false
    
    init(currency: Currency) {
        self.currency = currency
        super.init(frame: CGRect(x: 0, y: 0, width: 216.0/UIScreen.main.scale, height: 216.0/UIScreen.main.scale))
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        addSubview(label)
        label.frame = bounds
        label.text = "\(currency.code.first!)"
        label.textColor = .white
        label.font = UIFont.customBold(size: 45.0)
        label.textAlignment = .center
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class TokenImageNoBackground: RenderedIconBase {
    
    static var cache = NSMutableDictionary()
    
    override func layoutSubviews() {
        guard !didLayout else { return }
        didLayout = true
        
        super.layoutSubviews()
        backgroundColor = .clear
    }
}

class TokenImageSquareBackground: RenderedIconBase {
    
    static var cache = NSMutableDictionary()
    
    override func layoutSubviews() {
        guard !didLayout else { return }
        didLayout = true
        
        super.layoutSubviews()
        backgroundColor = currency.colors.0
        layer.cornerRadius = 6.0
        layer.masksToBounds = true
    }
}

extension RenderedIconBase {
    var renderedImage: UIImage? {
        let cache = (self is TokenImageNoBackground) ? TokenImageNoBackground.cache : TokenImageSquareBackground.cache
        
        if let cachedImage = cache[currency.code] as? UIImage {
            return cachedImage
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(bounds: bounds, format: format)
        let image = renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
        cache[currency.code] = image
        return image
    }
}
