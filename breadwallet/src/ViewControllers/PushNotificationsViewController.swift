//
//  PushNotificationsViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-04-05.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import UIKit
import UserNotifications

class PushNotificationsViewController: UIViewController, Trackable {

    private let toggleLabel = UILabel.wrapping(font: Theme.body1, color: Theme.primaryText)
    private let body = UILabel.wrapping(font: Theme.body2, color: Theme.secondaryText)
    private let toggle = UISwitch()
    private let separator = UIView()
    private let openSettingsButton = BRDButton(title: S.Button.openSettings, type: .primary)
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    var areNotificationsEnabled: Bool {
        return Store.state.isPushNotificationsEnabled
    }
        
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        saveEvent(context: .pushNotifications, screen: .pushNotificationSettings, event: .appeared)
    }
    
    override func viewDidLoad() {
        addSubviews()
        addConstraints()
        setData()
        listenForForegroundNotification()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        checkNotificationsSettings()
    }
    
    private func checkNotificationsSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            guard let `self` = self else { return }
            DispatchQueue.main.async {
                self.updateForNotificationStatus(status: settings.authorizationStatus)
            }
        }
    }

    private func updateForNotificationStatus(status: UNAuthorizationStatus) {
        self.body.text = bodyText(notificationsStatus: status)
        toggle.isEnabled = (status == .authorized)
        if !toggle.isEnabled {
            toggle.setOn(false, animated: false)
        }
        openSettingsButton.isHidden = (status == .authorized)
    }
    
    @objc private func willEnterForeground() {
        checkNotificationsSettings()
    }
    
    private func listenForForegroundNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    private func addSubviews() {
        view.addSubview(body)
        view.addSubview(toggleLabel)
        view.addSubview(toggle)
        view.addSubview(separator)
        view.addSubview(openSettingsButton)
    }

    private func addConstraints() {
        
        toggle.constrain([
            toggle.centerYAnchor.constraint(equalTo: toggleLabel.centerYAnchor),
            toggle.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -C.padding[2])
            ])
        
        toggle.setContentCompressionResistancePriority(.required, for: .horizontal)

        toggleLabel.constrain([
            toggleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: C.padding[2]),
            toggleLabel.leftAnchor.constraint(equalTo: view.leftAnchor, constant: C.padding[2]),
            toggleLabel.rightAnchor.constraint(equalTo: toggle.leftAnchor, constant: -C.padding[2])
            ])
        
        separator.constrain([
            separator.heightAnchor.constraint(equalToConstant: 1),
            separator.topAnchor.constraint(equalTo: toggle.bottomAnchor, constant: C.padding[2]),
            separator.leftAnchor.constraint(equalTo: view.leftAnchor),
            separator.rightAnchor.constraint(equalTo: view.rightAnchor)
            ])
        
        body.constrain([
            body.leftAnchor.constraint(equalTo: view.leftAnchor, constant: C.padding[2]),
            body.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: C.padding[1]),
            body.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2])
            ])
        
        openSettingsButton.constrain([
            openSettingsButton.heightAnchor.constraint(equalToConstant: C.Sizes.buttonHeight),
            openSettingsButton.leftAnchor.constraint(equalTo: view.leftAnchor, constant: C.padding[2]),
            openSettingsButton.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -C.padding[2]),
            openSettingsButton.topAnchor.constraint(equalTo: body.bottomAnchor, constant: C.padding[3])
            ])
    }
    
    private func bodyText(notificationsStatus: UNAuthorizationStatus) -> String {
        if notificationsStatus == .authorized {
            return areNotificationsEnabled ? S.PushNotifications.enabledBody : S.PushNotifications.disabledBody
        } else {
            return S.PushNotifications.enableInstructions
        }
    }
    
    private func setData() {
        title = S.Settings.notifications
        
        view.backgroundColor = Theme.primaryBackground
        separator.backgroundColor = Theme.tertiaryText
        
        toggleLabel.text = S.PushNotifications.label
        toggleLabel.textColor = Theme.primaryText
        
        toggle.isOn = areNotificationsEnabled
        toggle.sendActions(for: .valueChanged)
        
        toggle.valueChanged = { [weak self] in
            guard let `self` = self else { return }
            if self.toggle.isOn {
                UNUserNotificationCenter.current().getNotificationSettings { settings in
                    DispatchQueue.main.async {
                        let status = settings.authorizationStatus
                        switch status {
                        case .authorized:
                            Store.perform(action: PushNotifications.SetIsEnabled(true))
                            Store.trigger(name: .registerForPushNotificationToken)
                            self.updateForNotificationStatus(status: .authorized)
                            self.saveEvent(context: .pushNotifications, screen: .pushNotificationSettings, event: .pushNotificationsToggleOn)
                        default:
                            break
                        }
                    }
                }
            } else {
                Store.perform(action: PushNotifications.SetIsEnabled(false))
                if let token = UserDefaults.pushToken {
                    Backend.apiClient.deletePushNotificationToken(token)
                }
                self.saveEvent(context: .pushNotifications, screen: .pushNotificationSettings, event: .pushNotificationsToggleOff)
                self.updateForNotificationStatus(status: .authorized)
            }
        }
        
        openSettingsButton.tap = { [weak self] in
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            guard let `self` = self else { return }
            
            self.saveEvent(context: .pushNotifications, screen: .pushNotificationSettings, event: .openNotificationSystemSettings)
            UIApplication.shared.open(url)
        }
    }
}
