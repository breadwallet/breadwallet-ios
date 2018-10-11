//
//  GetUserEmailPrompt.swift
//  breadwallet
//
//  Created by Ray Vander Veen on 2018-10-07.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import UIKit

//
// Extends the Prompt view to provide an email input field and custom image.
//
class GetUserEmailPrompt : Prompt {
    
    let emailInputHeight: CGFloat = 36.0
    let continueButtonHeight: CGFloat = 36.0
    let continueButtonWidth: CGFloat = 90.0
    let imageViewTrailingMargin: CGFloat = -50.0
    
    let emailInput: UITextField = UITextField()
    let imageView: UIImageView = UIImageView()
    let successFootnoteLabel: UILabel = UILabel()
    
    var presenter: UIViewController?
    
    init() {
        super.init(type: .email)
    }
    
    override var shouldHandleTap: Bool {
        return true
    }
    
    override func setup() {
        super.setup()
        
        title.textColor = .darkPromptTitleColor
        body.textColor = .darkPromptBodyColor
        successFootnoteLabel.textColor = .darkPromptBodyColor
        
        successFootnoteLabel.isHidden = true
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

            // disable the submit button while we're hitting the API
            self.enableDisableSubmitButton(enable: false)
            
            Backend.apiClient.subscribeToEmailUpdates(emailAddress: emailAddress,callback: { [unowned self] (successful) in
                UserDefaults.hasSubscribedToEmailUpdates = successful

                self.updateViewOnEmailSubmissionResult(successful: successful)
                
                if !successful  {
                    self.showErrorOnEmailSubscriptionFailure()
                }
            })
        }// continue tap handler
        
        setUpEmailInput()
        setUpImageView()
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
        successFootnoteLabel.isHidden = false
        
        title.text = S.Prompts.Email.successTitle
        body.text = S.Prompts.Email.successBody
        successFootnoteLabel.text = S.Prompts.Email.successFootnote
        
        imageView.image = UIImage(named: "Partyhat")
    }
    
    override var containerBackgroundColor: UIColor {
        return .darkPromptBackground
    }
    
    override func addSubviews() {
        super.addSubviews()
        
        container.addSubview(emailInput)
        container.addSubview(imageView)
        container.addSubview(successFootnoteLabel)
    }
    
    private func setUpImageView() {
        imageView.contentMode = .center
        imageView.image = UIImage(named: "Loudspeaker")
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
        title.constrain([
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: C.padding[2]),
            title.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -C.padding[2]),
            title.topAnchor.constraint(equalTo: container.topAnchor, constant: C.padding[2])])
        body.constrain([
            body.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: C.padding[2]),
            body.trailingAnchor.constraint(equalTo: imageView.leadingAnchor, constant: -C.padding[1]),
            body.topAnchor.constraint(equalTo: title.bottomAnchor, constant: C.padding[1])])
        
        // Place the Dismiss ('x') button in the top-right corner. The 'x' image is 12x12
        // but the button itself should be larger so there's a decent tappable area. The
        // padding (8) and dimensions below (24x24) will achieve this with visual top and 
        // right margins of 14 around the 'x' itself.
        dismissButton.constrain([
            dismissButton.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            dismissButton.rightAnchor.constraint(equalTo: container.rightAnchor, constant: -8),
            dismissButton.widthAnchor.constraint(equalToConstant: 24),
            dismissButton.heightAnchor.constraint(equalToConstant: 24),
            ])
        
        continueButton.constrain([
            continueButton.topAnchor.constraint(equalTo: body.bottomAnchor, 
                                                constant: C.padding[2]),
            continueButton.widthAnchor.constraint(equalToConstant: continueButtonWidth),
            continueButton.heightAnchor.constraint(equalToConstant: continueButtonHeight),
            continueButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, 
                                                     constant: -C.padding[2]),
            continueButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, 
                                                   constant: -C.padding[2])
            ])
        
        emailInput.constrain([
            emailInput.topAnchor.constraint(equalTo: body.bottomAnchor, constant: C.padding[2]),
            emailInput.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: C.padding[2]),
            emailInput.trailingAnchor.constraint(equalTo: continueButton.leadingAnchor, constant: -10),
            emailInput.heightAnchor.constraint(equalToConstant: emailInputHeight),
            ])
        
        // The icon (defaults to loudspeaker) goes above the Submit button, slightly offset to the left.
        // The 60x60 image size will accommodate both images that we display.
        imageView.constrain([
            imageView.widthAnchor.constraint(equalToConstant: 60),
            imageView.heightAnchor.constraint(equalToConstant: 60),
            imageView.bottomAnchor.constraint(equalTo: body.bottomAnchor),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: imageViewTrailingMargin),
            imageView.leadingAnchor.constraint(equalTo: continueButton.leadingAnchor, constant: -(C.padding[1])),
            ])
        
        successFootnoteLabel.constrain([
            successFootnoteLabel.leftAnchor.constraint(equalTo: emailInput.leftAnchor, constant: 0),
            successFootnoteLabel.centerYAnchor.constraint(equalTo: emailInput.centerYAnchor, constant: 0),
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
extension GetUserEmailPrompt : UITextFieldDelegate {
    
    private func enableOrDisableSubmitButton(emailAddressText: String?) {
        guard let text = emailAddressText, text.count > 0 else {
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
