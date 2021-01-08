// 
//  CloudBackupView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2020-07-28.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import SwiftUI
import Combine

@available(iOS 13.6, *)
struct CloudBackupView: View {
    
    @SwiftUI.State private var isBackupOnAtLoad: Bool
    @SwiftUI.State private var isBackupOn: Bool
    @SwiftUI.State private var showingDetail = false
    @SwiftUI.State private var didToggle = false
    @SwiftUI.State private var didSeeFirstToggle = false
    @SwiftUI.State private var didEnableKeyChain = false
    @SwiftUI.State private var showingDisableAlert = false
  
    private let synchronizer: BackupSynchronizer
    
    init(synchronizer: BackupSynchronizer) {
        self.synchronizer = synchronizer
        _isBackupOn = SwiftUI.State(initialValue: synchronizer.isBackedUp)
        _isBackupOnAtLoad = SwiftUI.State(initialValue: synchronizer.isBackedUp)
    }
    
    @ViewBuilder
    var body: some View {
        mainStack()
            .if(isBackupOnAtLoad) {
                self.addAlert(content: $0)
            }
            .if(!isBackupOnAtLoad) {
                self.addSheet(content: $0)
            }
            .if(self.synchronizer.context == .onboarding) {
                self.addNavItem(content: $0)
            }
    }
    
    private func mainStack() -> some View {
        ZStack {
            Rectangle()
                .fill(Color(Theme.primaryBackground))
            VStack {
                CloudBackupViewBody()
                Toggle(isOn: $isBackupOn) {
                    Text(S.CloudBackup.mainToggleTitle)
                        .font(Font(Theme.body1))
                        .foregroundColor(Color(Theme.secondaryText))
                }.onReceive(Just(isBackupOn), perform: self.onToggleChange)
                    .if(!E.isIPhone5, content: { $0.padding() })
                    .if(E.isIPhone5, content: { $0.padding([.leading, .trailing]) })
                HStack {
                    Image(systemName: "exclamationmark.circle")
                        .resizable()
                        .frame(width: 36.0, height: 36.0)
                        .foregroundColor(Color(Theme.error))
                        .padding(.leading)
                    BodyText(S.CloudBackup.mainWarning, style: .seconday)
                        .foregroundColor(Color(Theme.secondaryText))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(nil)
                    .if(!E.isIPhone5, content: { $0.padding() })
                    .if(E.isIPhone5, content: { $0.padding(4.0) })
                }.background(Color(Theme.secondaryBackground))
                .cornerRadius(4.0)
                .padding()
            }
        }
        .edgesIgnoringSafeArea(.all)

    }
    
    private func addAlert<Content: View>(content: Content) -> some View {
        return content.alert(isPresented: $showingDisableAlert) {
            SwiftUI.Alert(title: Text(S.WalletConnectionSettings.turnOff),
                          message: Text(S.CloudBackup.mainWarningConfirmation),
                          primaryButton: .default(Text(S.Button.cancel), action: {
                            self.isBackupOn = true
                            self.didToggle = false
                          }), secondaryButton: .destructive(Text(S.WalletConnectionSettings.turnOff), action: {
                            self.didToggle = false
                            self.isBackupOnAtLoad = false
                            self.synchronizer.deleteBackup()
                          }))
        }
    }
    
    private func addSheet<Content: View>(content: Content) -> some View {
        return content.sheet(isPresented: $showingDetail, onDismiss: self.onEnableKeychainDismiss, content: {
            EnableKeychainView(completion: self.onEnableKeychain)
        })
    }
    
    private func addNavItem<Content: View>(content: Content) -> some View {
        return content.navigationBarBackButtonHidden(true)
            .navigationBarItems(trailing:
                Button(action: { self.synchronizer.skipBackup() },
                       label: { BodyText(S.Button.skip, style: .primary)
                            .foregroundColor(Color(Theme.primaryText))
                        }))
    }
    
    private func onToggleChange(value: Bool) {
        //SWIFTUI:HACK - onReceive gets called at launch - we want to ignore the first result
        guard didSeeFirstToggle else { didSeeFirstToggle = true; return }

        //Turn off mode
        if isBackupOnAtLoad {
            if value == false && !didToggle {
                showingDisableAlert = true
                didToggle = true
            }
        //Turn on mode
        } else {
            if value == true && !didToggle {
                showingDetail = true
                didToggle = true
            }
        }
    }
    
    private func onEnableKeychain() {
        didEnableKeyChain = true
        showingDetail = false
    }
    
    private func onEnableKeychainDismiss() {
        if didEnableKeyChain {
            synchronizer.enableBackup { success in
                if success == false {
                    self.isBackupOn = false
                    self.didToggle = false
                } else {
                    self.didToggle = false
                    self.isBackupOnAtLoad = true
                }
            }
        } else {
            isBackupOn = false
        }
        didToggle = false
    }
}

@available(iOS 13.6, *)
struct CloudBackupViewBody: View {
    var body: some View {
        Group {
            CloudBackupIcon(style: .up)
            Text(S.CloudBackup.mainTitle)
                .font(Font(Theme.h1Title))
                .foregroundColor(.white)
            Text(S.CloudBackup.mainBody)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)
                .font(Font(Theme.body1))
                .foregroundColor(Color(Theme.secondaryText))
                .padding()
        }
    }
}

enum CloudBackupIconStyle: String {
    case up = "icloud.and.arrow.up"
    case down = "icloud.and.arrow.down"
}

@available(iOS 13.6, *)
struct CloudBackupIcon: View {
    
    let style: CloudBackupIconStyle
    
    private var imageSize: CGFloat {
        if E.isIPhone5 {
            return 60
        } else if E.isIPhone6 {
            return 80
        }
        return 150
    }
    
    var body: some View {
        LinearGradient(gradient: Gradient(colors: [Color(UIColor.gradientStart), Color(UIColor.gradientEnd)]), startPoint: .topLeading, endPoint: .bottomTrailing)
            .mask(Image(systemName: style.rawValue)
                .resizable()
                .scaledToFit()
                .frame(width: imageSize, height: imageSize)
        )
        .frame(width: imageSize, height: imageSize)
    }
}

@available(iOS 13.6, *)
struct CloudBackupView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                CloudBackupView(synchronizer: CloudBackupView_Previews.synchronizer)
            }
            CloudBackupView(synchronizer: CloudBackupView_Previews.synchronizer)
        }
    }
    
    // swiftlint:disable force_try
    private static let keyStore = try! KeyStore.create()
    private static let synchronizer = BackupSynchronizer(context: .onboarding,
                                                         keyStore: CloudBackupView_Previews.keyStore,
                                                         navController: UINavigationController())
}
