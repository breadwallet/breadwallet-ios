//
//  GetUserEmailPromptView.swift
//  breadwallet
//
//  Created by Ray Vander Veen on 2018-10-07.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import UIKit

//
// Extends the Prompt view to include an email input field and custom image.
//
class GetUserEmailPromptView: PromptView {
    
    let emailInputHeight: CGFloat = 36.0
    let footerHeight: CGFloat = 36.0
    
    let emailInput: UITextField = UITextField()
    let successFootnoteLabel: UILabel = UILabel()
    
    let footerView = UIView()
    var footerViewHeightConstraint: NSLayoutConstraint?
    
    let emailCollector: EmailCollectingPrompt
    let presenter: UIViewController
    
    var shouldShowFootnoteLabel: Bool {
        if let footnote = emailCollector.confirmationFootnote, !footnote.isEmpty {
            return true
        }
        return false
    }
    
    init(prompt: EmailCollectingPrompt, presenter: UIViewController) {
        self.presenter = presenter
        self.emailCollector = prompt
        super.init(prompt: prompt)
    }
    
    override var shouldHandleTap: Bool {
        return true
    }
    
    override var shouldAddContinueButton: Bool {
        return false    // tells the superview not to add the Continue button
    }
    
    override func setup() {
        super.setup()
        
        title.textColor = Theme.primaryText
        body.textColor = Theme.secondaryText
        
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
                                                      emailList: self.emailCollector.emailList ?? "",
                                                      callback: { [unowned self] (successful) in
                self.emailCollector.didSubscribe()
                
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
        setUpContinueButton()
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
        presenter.showErrorMessage(S.Alert.somethingWentWrong)
    }
        
    private func updateViewOnEmailSubmissionResult(successful: Bool) {
        guard successful else {
            // Unsuccessful, so re-enable the Submit button.
            enableDisableSubmitButton(enable: true)
            return
        }
        
        continueButton.isHidden = true
        emailInput.isHidden = true
        
        title.text = emailCollector.confirmationTitle
        body.text = emailCollector.confirmationBody
        
        if let imageName = emailCollector.confirmationImageName {
            imageView.image = UIImage(named: imageName)
        }

        if shouldShowFootnoteLabel, let footnote = emailCollector.confirmationFootnote {
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
        return Theme.secondaryBackground
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
        if let imageName = prompt.imageName {
            imageView.image = UIImage(named: imageName)
        }
    }
        
    private func setUpEmailInput() {
        emailInput.delegate = self
        
        emailInput.backgroundColor = Theme.tertiaryBackground
        emailInput.layer.cornerRadius = 2.0
        emailInput.textColor = Theme.primaryText
        emailInput.font = UIFont.emailPlaceholder()
        emailInput.attributedPlaceholder = NSAttributedString(string: S.Prompts.Email.emailPlaceholder,
                                                              attributes: [ NSAttributedString.Key.foregroundColor: UIColor.emailPlaceholderText ])
        emailInput.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: emailInputHeight))
        emailInput.leftViewMode = .always
        emailInput.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: emailInputHeight))
        emailInput.rightViewMode = .always
        
        emailInput.keyboardType = .emailAddress
        emailInput.autocapitalizationType = .none
        emailInput.autocorrectionType = .no
        
        emailInput.returnKeyType = .done
    }
    
    private func setUpContinueButton() {
        continueButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: C.padding[2], bottom: 0, right: C.padding[2])
    }
    
    override func setupConstraints() {
        super.setupConstraints()

        let constraints = [
            footerView.heightAnchor.constraint(equalToConstant: footerHeight),
            footerView.topAnchor.constraint(equalTo: body.bottomAnchor, constant: C.padding[2]),
            footerView.leadingAnchor.constraint(equalTo: body.leadingAnchor),
            footerView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            footerView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -(C.padding[2]))
        ]
        
        footerView.constrain(constraints)
        footerViewHeightConstraint = constraints[0]   // save for later if we shrink the prompt height
        
        continueButton.constrain([
            continueButton.heightAnchor.constraint(equalToConstant: footerHeight),
            continueButton.bottomAnchor.constraint(equalTo: footerView.bottomAnchor),
            continueButton.trailingAnchor.constraint(equalTo: footerView.trailingAnchor)
            ])

        emailInput.constrain([
            emailInput.topAnchor.constraint(equalTo: footerView.topAnchor),
            emailInput.leadingAnchor.constraint(equalTo: footerView.leadingAnchor),
            emailInput.bottomAnchor.constraint(equalTo: footerView.bottomAnchor),
            emailInput.trailingAnchor.constraint(equalTo: continueButton.leadingAnchor)
            ])
    }
    
    private func enableDisableSubmitButton(enable: Bool) {
        // Note: In the email prompt, the inherited continue button is labeled 'Submit'.
        continueButton.isEnabled = enable
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
