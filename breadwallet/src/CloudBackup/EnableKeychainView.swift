// 
//  EnableKeychainView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2020-08-03.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import SwiftUI

@available(iOS 13.6, *)
struct EnableKeychainView: View {
    
    @SwiftUI.State private var isKeychainToggleOn: Bool = false
    
    var completion: () -> Void
    
    var body: some View {
        VStack {
            TitleText(S.CloudBackup.enableTitle)
                .padding(.bottom)
            VStack(alignment: .leading) {
                BodyText(S.CloudBackup.enableBody1, style: .primary)
                    .padding(.bottom, 8.0)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(nil)
                ForEach(0..<steps.count) { i in
                    HStack(alignment: .top) {
                        BodyText("\(i + 1).", style: .primary)
                            .frame(width: 14.0)
                        BodyText(steps[i], style: .primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(nil)
                    }
                }
                BodyText(S.CloudBackup.enableBody2, style: .primary)
                    .padding(.top, 8.0)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(nil)
            }
            Image("Keychain")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding([.leading, .trailing], 24.0)
            HStack {
                RadioButton(isOn: self.$isKeychainToggleOn)
                    .frame(width: 44.0, height: 44.0)
                BodyText(S.CloudBackup.understandText, style: .primary)
            }.padding()
            Button(action: self.completion, label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 4.0)
                        .fill(Color(self.isKeychainToggleOn ? Theme.accent : UIColor.secondaryButton))
                    Text(S.CloudBackup.enableButton)
                        .font(Font(Theme.body1))
                        .foregroundColor(Color(Theme.primaryText))
                }
            })
            .frame(height: 44.0)
            .disabled(!self.isKeychainToggleOn)
            .padding([.leading, .trailing, .bottom])
        }.padding()
    }
}

@available(iOS 13.6, *)
struct EnableKeychainView_Previews: PreviewProvider {
    static var previews: some View {
        EnableKeychainView(completion: {})
    }
}

private let steps = [
    S.CloudBackup.step1,
    S.CloudBackup.step2,
    S.CloudBackup.step3,
    S.CloudBackup.step4
]
