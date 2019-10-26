//
//  SegwitViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-10-11.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import UIKit

class SegwitViewController: UIViewController {
    
    let logo = UIImageView(image: UIImage(named: "SegWitLogo"))
    let label = UILabel.wrapping(font: .customBody(size: 16.0), color: .white)
    let button = BRDButton(title: S.Segwit.enable, type: .primary)
    let confirmView = EnableSegwitView()
    let enabled = SegwitEnabledView()
    
    var buttonXConstraintStart: NSLayoutConstraint?
    var buttonXConstraintEnd: NSLayoutConstraint?
    var confirmXConstraintStart: NSLayoutConstraint?
    var confirmXConstraintEnd: NSLayoutConstraint?
    var confirmXConstraintFinal: NSLayoutConstraint?
    var enabledYConstraintStart: NSLayoutConstraint?
    var enabledYConstraintEnd: NSLayoutConstraint?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addSubviews()
        addConstraints()
        setInitialData()
    }
    
    private func addSubviews() {
        view.addSubview(logo)
        view.addSubview(label)
        view.addSubview(button)
        view.addSubview(confirmView)
        view.addSubview(enabled)
    }
    
    private func addConstraints() {
        logo.constrain([
            logo.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logo.topAnchor.constraint(equalTo: safeTopAnchor, constant: C.padding[2]) ])
        label.constrain([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[3]),
            label.topAnchor.constraint(equalTo: logo.bottomAnchor, constant: C.padding[3]),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[3])])
        
        buttonXConstraintStart = button.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        buttonXConstraintEnd = button.trailingAnchor.constraint(equalTo: view.leadingAnchor, constant: -C.padding[2])
        button.constrain([
            buttonXConstraintStart,
            button.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -C.padding[6]),
            button.bottomAnchor.constraint(equalTo: safeBottomAnchor, constant: -C.padding[3]),
            button.heightAnchor.constraint(equalToConstant: 48.0)])
        
        confirmXConstraintStart = confirmView.leadingAnchor.constraint(equalTo: view.trailingAnchor, constant: C.padding[2])
        confirmXConstraintEnd = confirmView.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        confirmXConstraintFinal = confirmView.trailingAnchor.constraint(equalTo: view.leadingAnchor, constant: -C.padding[2])
        confirmView.constrain([
            confirmView.bottomAnchor.constraint(equalTo: safeBottomAnchor, constant: -C.padding[3]),
            confirmXConstraintStart,
            confirmView.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -C.padding[6])])
        
        enabledYConstraintStart = enabled.topAnchor.constraint(equalTo: safeBottomAnchor, constant: 50.0)
        enabledYConstraintEnd = enabled.bottomAnchor.constraint(equalTo: safeBottomAnchor, constant: -C.padding[2])
        enabled.constrain([
            enabledYConstraintStart,
            enabled.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            enabled.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -C.padding[6])])
    }
    
    private func setInitialData() {
        view.backgroundColor = Theme.primaryBackground
        view.clipsToBounds = true //Some subviews are placed just offscreen so they can be animated into view
        label.text = S.Segwit.confirmationInstructionsInstructions
        
        button.tap = { [weak self] in
            self?.showConfirmView()
        }
        
        confirmView.didCancel = { [weak self] in
            self?.hideConfirmView()
        }
        
        confirmView.didContinue = { [weak self] in
            self?.didContinue()
        }
        
        enabled.home.tap = { [weak self] in
            self?.navigationController?.dismiss(animated: true, completion: nil)
        }
        
    }
    
    private func didContinue() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        UserDefaults.hasOptedInSegwit = true
        Store.trigger(name: .optInSegWit)
        Backend.apiClient.sendEnableSegwit()
        UIView.spring(0.6, animations: {
            self.confirmXConstraintEnd?.isActive = false
            self.enabledYConstraintStart?.isActive = false
            NSLayoutConstraint.activate([self.confirmXConstraintFinal!, self.enabledYConstraintEnd!])
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.enabled.checkView.drawCircle()
            self.enabled.checkView.drawCheckBox()
        })
    }
    
    private func hideConfirmView() {
        UIView.spring(C.animationDuration, animations: {
            self.button.isHidden = false
            self.confirmXConstraintEnd?.isActive = false
            self.buttonXConstraintEnd?.isActive = false
            NSLayoutConstraint.activate([self.confirmXConstraintStart!, self.buttonXConstraintStart!])
            self.view.layoutIfNeeded()
        }, completion: { _ in
        })
    }
    
    private func showConfirmView() {
        UIView.spring(C.animationDuration, animations: {
            self.buttonXConstraintStart?.isActive = false
            self.confirmXConstraintStart?.isActive = false
            NSLayoutConstraint.activate([self.confirmXConstraintEnd!, self.buttonXConstraintEnd!])
            self.view.layoutIfNeeded()
        }, completion: { _ in
        })
    }
    
}
