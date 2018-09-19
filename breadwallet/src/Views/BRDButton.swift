//
//  BRDButton.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-15.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

enum ButtonType {
    case primary
    case secondary
    case tertiary
    case blackTransparent
    case secondaryTransparent
    case search
}

private let minTargetSize: CGFloat = 48.0

class BRDButton: UIControl {

    init(title: String, type: ButtonType) {
        self.title = title
        self.type = type
        super.init(frame: .zero)
        accessibilityLabel = title
        setupViews()
    }

    init(title: String, type: ButtonType, image: UIImage) {
        self.title = title
        self.type = type
        self.image = image
        super.init(frame: .zero)
        accessibilityLabel = title
        setupViews()
    }

    var isToggleable = false
    var title: String {
        didSet {
            label.text = title
        }
    }
    var image: UIImage? {
        didSet {
            imageView = imageView ?? UIImageView()
            imageView?.image = image
        }
    }
    private let type: ButtonType
    private let container = UIView()
    private let label = UILabel()
    private let cornerRadius: CGFloat = 6.0
    private var imageView: UIImageView?

    override var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                UIView.animate(withDuration: 0.04, animations: {
                    let shrink = CATransform3DMakeScale(0.97, 0.97, 1.0)
                    let translate = CATransform3DTranslate(shrink, 0, 4.0, 0)
                    self.container.layer.transform = translate
                })
            } else {
                UIView.animate(withDuration: 0.04, animations: {
                    self.container.transform = CGAffineTransform.identity
                })
            }
        }
    }

    override var isSelected: Bool {
        didSet {
            guard isToggleable else { return }
            if type == .tertiary || type == .search {
                if isSelected {
                    container.layer.borderColor = UIColor.primaryButton.cgColor
                    imageView?.tintColor = .primaryButton
                    label.textColor = .primaryButton
                } else {
                    setColors()
                }
            }
        }
    }
    
    override var isEnabled: Bool {
        didSet {
            setColors()
        }
    }

    private func setupViews() {
        addContent()
        setColors()
        addTarget(self, action: #selector(BRDButton.touchUpInside), for: .touchUpInside)
        setContentCompressionResistancePriority(UILayoutPriority.required, for: .horizontal)
        label.setContentCompressionResistancePriority(UILayoutPriority.required, for: .horizontal)
        setContentHuggingPriority(UILayoutPriority.required, for: .horizontal)
        label.setContentHuggingPriority(UILayoutPriority.required, for: .horizontal)
    }

    private func addContent() {
        addSubview(container)
        container.backgroundColor = .primaryButton
        container.layer.cornerRadius = cornerRadius
        container.isUserInteractionEnabled = false
        container.constrain(toSuperviewEdges: nil)
        label.text = title
        label.textColor = .white
        label.textAlignment = .center
        label.isUserInteractionEnabled = false
        label.font = UIFont.customBody(size: 16.0)
        configureContentType()
    }

    private func configureContentType() {
        if let icon = image {
            setupImageOption(icon: icon)
        } else {
            setupLabelOnly()
        }
    }

    private func setupImageOption(icon: UIImage) {
        let content = UIView()
        let iconImageView = UIImageView(image: icon.withRenderingMode(.alwaysTemplate))
        iconImageView.contentMode = .scaleAspectFit
        container.addSubview(content)
        content.addSubview(label)
        content.addSubview(iconImageView)
        content.constrainToCenter()
        iconImageView.constrainLeadingCorners()
        label.constrainTrailingCorners()
        iconImageView.constrain([
            iconImageView.constraint(toLeading: label, constant: -C.padding[1]) ])
        imageView = iconImageView
    }

    private func setupLabelOnly() {
        container.addSubview(label)
        label.constrain(toSuperviewEdges: UIEdgeInsets(top: C.padding[1], left: C.padding[1], bottom: -C.padding[1], right: -C.padding[1]))
    }

    private func setColors() {
        switch type {
        case .primary:
            container.backgroundColor = isEnabled ? .primaryButton : UIColor.lightGray
            label.textColor = isEnabled ? .primaryText : UIColor.primaryText.withAlphaComponent(0.75)
            container.layer.borderColor = nil
            container.layer.borderWidth = 0.0
            imageView?.tintColor = .white
        case .secondary:
            container.backgroundColor = .secondaryButton
            label.textColor = .darkText
            container.layer.borderColor = UIColor.secondaryBorder.cgColor
            container.layer.borderWidth = 1.0
            imageView?.tintColor = .darkText
        case .tertiary:
            container.backgroundColor = .secondaryButton
            label.textColor = .grayTextTint
            container.layer.borderColor = UIColor.secondaryBorder.cgColor
            container.layer.borderWidth = 1.0
            imageView?.tintColor = .grayTextTint
        case .blackTransparent:
            container.backgroundColor = .clear
            label.textColor = .darkText
            container.layer.borderColor = UIColor.darkText.cgColor
            container.layer.borderWidth = 1.0
            imageView?.tintColor = .grayTextTint
        case .secondaryTransparent:
            container.backgroundColor = .transparentButton
            label.textColor = .white
            container.layer.borderColor = nil
            container.layer.borderWidth = 0.0
            imageView?.tintColor = .white
        case .search:
            label.font = UIFont.customBody(size: 13.0)
            container.backgroundColor = .secondaryButton
            label.textColor = .grayTextTint
            container.layer.borderColor = UIColor.secondaryBorder.cgColor
            container.layer.borderWidth = 1.0
            imageView?.tintColor = .grayTextTint
        }
    }

    open override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden || isUserInteractionEnabled else { return nil }
        let deltaX = max(minTargetSize - bounds.width, 0)
        let deltaY = max(minTargetSize - bounds.height, 0)
        let hitFrame = bounds.insetBy(dx: -deltaX/2.0, dy: -deltaY/2.0)
        return hitFrame.contains(point) ? self : nil
    }

    @objc private func touchUpInside() {
        isSelected = !isSelected
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
