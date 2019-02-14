//
//  GetUserEmailPromptView.swift
//  breadwallet
//
//  Created by Ray Vander Veen on 2018-10-07.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import UIKit

//
// Extends the Prompt view to include an email input field and custom image.
//
class GetUserEmailPromptView: PromptView {
    
    let emailInputHeight: CGFloat = 36.0
    let footerHeight: CGFloat = 36.0
    let continueButtonHeight: CGFloat = 44.0
    let continueButtonWidth: CGFloat = 90.0
    let imageViewTrailingMargin: CGFloat = -50.0
    let imageSize: CGFloat = 44
    
    let emailInput: UITextField = UITextField()
    let imageView: UIImageView = UIImageView()
    let successFootnoteLabel: UILabel = UILabel()
    
    let footerView = UIView()
    var footerViewHeightConstraint: NSLayoutConstraint?
    
    var presenter: UIViewController?
    
    var shouldShowFootnoteLabel: Bool {
        if let footnote = prompt.successFootnote(), !footnote.isEmpty {
            return true
        }
        return false
    }
    
    init(prompt: Prompt, presenter: UIViewController?) {
        super.init(prompt: prompt)
        self.presenter = presenter
    }
    
    override var shouldHandleTap: Bool {
        return true
    }
    
    override var shouldAddContinueButton: Bool {
        // return false because we'll handle adding positioning the continue button rather
        // than leaving it to the super view
        return false
    }
    
    override func setup() {
        super.setup()
        
        title.textColor = .darkPromptTitleColor
        body.textColor = .darkPromptBodyColor
        successFootnoteLabel.textColor = .darkPromptBodyColor
        
        successFootnoteLabel.textColor = body.textColor
        successFootnoteLabel.font = body.font

        // The 'Continue' action text for the email prompt is "Submit"
        continueButton.setTitle(S.Button.submit, for: .normal)
        
        // The 'Dismiss' action for the email prompt has no text; uses an 'x' image instead.
        dismissButton.setTitle("", for: .normal)
        
        // The continue button is disabled until the user enters a valid email address.
        enableDisableSubmitButton(enable: false)
        
        // Override the continue (Submit) button tap handler
        continueButton.tap = { [unowned self] in
            
            // Note: The submit button is not enabled unless the user has entered a valid
            // email address. Guard anyway so we don't have to force unwrap the text field's text.
            guard let emailAddress = self.emailInput.text else { return }

            self.emailInput.resignFirstResponder()
            
            // disable the submit button while we're hitting the API
            self.enableDisableSubmitButton(enable: false)
            
            Backend.apiClient.subscribeToEmailUpdates(emailAddress: emailAddress,
                                                      emailList: self.prompt.emailListParameter(),
                                                      callback: { [unowned self] (successful) in
                UserDefaults.hasSubscribedToEmailUpdates = successful

                self.updateViewOnEmailSubmissionResult(successful: successful)
                
                if !successful {
                    self.showErrorOnEmailSubscriptionFailure()
                } else {
                    self.scheduleAutoDismiss()
                }
            })
        }// continue tap handler
        
        footerView.backgroundColor = backgroundColor
        
        setUpEmailInput()
        setUpImageView()
    }
    
    private func scheduleAutoDismiss() {
        let autoDismissDelay = 5.0
        DispatchQueue.main.asyncAfter(deadline: .now() + autoDismissDelay ) { [weak self] in
            guard let dismissBtn = self?.dismissButton, let tapHandler = dismissBtn.tap else {
                return
            }
            tapHandler()
        }
    }
    
    private func showErrorOnEmailSubscriptionFailure() {
        if let presenter = self.presenter {
            presenter.showErrorMessage(S.Alert.somethingWentWrong)
        }
    }
        
    private func updateViewOnEmailSubmissionResult(successful: Bool) {
        guard successful else {
            // Unsuccessful, so re-enable the Submit button.
            enableDisableSubmitButton(enable: true)
            return
        }
        
        continueButton.isHidden = true
        emailInput.isHidden = true
        
        title.text = prompt.title(for: .confirmation)
        body.text = prompt.body(for: .confirmation)
        
        if let imageName = prompt.imageName(for: .confirmation) {
            imageView.image = UIImage(named: imageName)
        }
        
        if shouldShowFootnoteLabel, let footnote = prompt.successFootnote() {
            footerView.addSubview(successFootnoteLabel)
            successFootnoteLabel.constrain([
                successFootnoteLabel.leadingAnchor.constraint(equalTo: footerView.leadingAnchor),
                successFootnoteLabel.trailingAnchor.constraint(equalTo: footerView.trailingAnchor, constant: -(C.padding[1])),
                successFootnoteLabel.centerYAnchor.constraint(equalTo: footerView.centerYAnchor)
                ])
            successFootnoteLabel.text = footnote
        } else {
            // shrink the footer view so we don't leave unnecessary blank space
            footerViewHeightConstraint?.constant = 0
        }
    }
    
    override var containerBackgroundColor: UIColor {
        return .darkPromptBackground
    }
    
    override func addSubviews() {
        super.addSubviews()
        
        container.addSubview(imageView)

        // The footer view contains the email input and the submit ('continue') button.
        container.addSubview(footerView)
        
        footerView.addSubview(emailInput)
        footerView.addSubview(continueButton)
    }
    
    private func setUpImageView() {
        imageView.contentMode = .scaleAspectFit
        if let imageName = prompt.imageName(for: .initialDisplay) {
            imageView.image = UIImage(named: imageName)
        }
    }
        
    private func setUpEmailInput() {
        emailInput.delegate = self
        
        emailInput.backgroundColor = UIColor.emailInputBackgroundColor
        emailInput.layer.cornerRadius = 2.0
        emailInput.textColor = .primaryText
        emailInput.font = UIFont.emailPlaceholder()
        emailInput.attributedPlaceholder = NSAttributedString(string: S.Prompts.Email.emailPlaceholder,
                                                              attributes: [ NSAttributedStringKey.foregroundColor: UIColor.emailPlaceholderText ])
        emailInput.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: emailInputHeight))
        emailInput.leftViewMode = .always
        emailInput.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: emailInputHeight))
        emailInput.rightViewMode = .always
        
        emailInput.keyboardType = .emailAddress
        emailInput.autocapitalizationType = .none
        emailInput.autocorrectionType = .no
        
        emailInput.returnKeyType = .done
    }
    
    override func setupConstraints() {
        container.constrain(toSuperviewEdges: UIEdgeInsets(top: C.padding[1],
                                                           left: 10.0,
                                                           bottom: -C.padding[1],
                                                           right: -10.0))
        
        // The icon (defaults to loudspeaker) goes above the Submit button, slightly offset to the left.
        // The 60x60 image size will accommodate both images that we display.
        imageView.constrain([
            imageView.widthAnchor.constraint(equalToConstant: imageSize),
            imageView.heightAnchor.constraint(equalToConstant: imageSize),
            imageView.topAnchor.constraint(equalTo: title.topAnchor, constant: 0),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: imageViewTrailingMargin)
            ])

        title.constrain([
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: C.padding[2]),
            title.trailingAnchor.constraint(equalTo: imageView.leadingAnchor, constant: -(C.padding[3])),
            title.topAnchor.constraint(equalTo: container.topAnchor, constant: C.padding[2])])
        
        body.constrain([
            body.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: C.padding[2]),
            body.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -C.padding[3]),
            body.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: C.padding[2])])

        // Place the Dismiss ('x') button in the top-right corner. The 'x' image is 12x12
        // but the button itself should be larger so there's a decent tappable area. The
        // padding (8) and dimensions below (24x24) will achieve this with visual top and 
        // right margins of 14 around the 'x' itself.
        dismissButton.constrain([
            dismissButton.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            dismissButton.rightAnchor.constraint(equalTo: container.rightAnchor, constant: -8),
            dismissButton.widthAnchor.constraint(equalToConstant: 24),
            dismissButton.heightAnchor.constraint(equalToConstant: 24)
            ])
        
        //let heightConstraint = footerView.heightAnchor.constraint(equalToConstant: footerHeight)
        let constraints = [
            footerView.heightAnchor.constraint(equalToConstant: footerHeight),
            footerView.topAnchor.constraint(equalTo: body.bottomAnchor, constant: C.padding[2]),
            footerView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: C.padding[2]),
            footerView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -(C.padding[2])),
            footerView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -(C.padding[1]))
        ]
        footerView.constrain(constraints)
        footerViewHeightConstraint = constraints[0]   // save for later if we shrink the prompt height
        
        continueButton.constrain([
            continueButton.topAnchor.constraint(equalTo: footerView.topAnchor),
            continueButton.bottomAnchor.constraint(equalTo: footerView.bottomAnchor),
            continueButton.trailingAnchor.constraint(equalTo: footerView.trailingAnchor),
            continueButton.widthAnchor.constraint(equalToConstant: continueButtonWidth)
            ])

        emailInput.constrain([
            emailInput.topAnchor.constraint(equalTo: footerView.topAnchor),
            emailInput.leadingAnchor.constraint(equalTo: footerView.leadingAnchor),
            emailInput.bottomAnchor.constraint(equalTo: footerView.bottomAnchor),
            emailInput.trailingAnchor.constraint(equalTo: continueButton.leadingAnchor, constant: -(C.padding[1]))
            ])
    }
    
    override func styleDismissButton() {
        let closeButtonImage = UIImage(named: "Close-X-small")
        dismissButton.setImage(closeButtonImage, for: .normal)
        dismissButton.backgroundColor = .clear
        dismissButton.tintColor = .white
    }
    
    override func styleContinueButton() {
        continueButton.backgroundColor = .clear
        continueButton.setBackgroundImage(UIImage(), for: .disabled)
        continueButton.setBackgroundImage(UIImage.imageForColor(.submitButtonEnabledBlue), for: .normal)
        continueButton.setTitleColor(.white, for: .normal)
    }

    private func enableDisableSubmitButton(enable: Bool) {
        // Note: In the email prompt, the inherited continue button is labeled 'Submit'.

        continueButton.isEnabled = enable
        
        continueButton.layer.borderWidth = 0.5
        continueButton.layer.borderColor = enable ? UIColor.clear.cgColor : UIColor.white.cgColor
        continueButton.layer.cornerRadius = 2.0
        continueButton.layer.masksToBounds = true                
    }
        
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// The main task of this extension is to enable or disable the Submit button
// as the user types, based on whether a valid email address has been entered.
extension GetUserEmailPromptView: UITextFieldDelegate {
    
    private func enableOrDisableSubmitButton(emailAddressText: String?) {
        guard let text = emailAddressText, !text.isEmpty else {
            enableDisableSubmitButton(enable: false)
            return
        }
        
        enableDisableSubmitButton(enable: text.isValidEmailAddress)
    }
    
    func textField(_ textField: UITextField, 
                   shouldChangeCharactersIn range: NSRange, 
                   replacementString string: String) -> Bool {
        
        // Check for a valid email address as the user types.
        if let text = textField.text,
            let textRange = Range(range, in: text) {
            let updatedText = text.replacingCharacters(in: textRange, with: string)
            enableOrDisableSubmitButton(emailAddressText: updatedText)            
        }
        
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
