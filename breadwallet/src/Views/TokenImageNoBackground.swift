//
//  TokenImageNoBackground.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-09-25.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import UIKit

class RenderedIconBase: UIView {
    
    fileprivate let label = UILabel()
    fileprivate let color: UIColor
    fileprivate let code: String
    fileprivate var didLayout = false
    
    init(code: String, color: UIColor) {
        self.color = color
        self.code = code
        super.init(frame: CGRect(x: 0, y: 0, width: 216.0/UIScreen.main.scale, height: 216.0/UIScreen.main.scale))
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        addSubview(label)
        label.frame = bounds
        label.text = "\(code.first!)"
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
        backgroundColor = color
        layer.cornerRadius = 6.0
        layer.masksToBounds = true
    }
}

extension RenderedIconBase {
    var renderedImage: UIImage? {
        let cache = (self is TokenImageNoBackground) ? TokenImageNoBackground.cache : TokenImageSquareBackground.cache
        
        if let cachedImage = cache[code] as? UIImage {
            return cachedImage
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(bounds: bounds, format: format)
        let image = renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
        cache[code] = image
        return image
    }
}
