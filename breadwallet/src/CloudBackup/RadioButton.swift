// 
//  RadioButton.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2020-08-11.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import SwiftUI

@available(iOS 13.6, *)
struct RadioButton: View {
    @SwiftUI.Binding var isOn: Bool
    
    private let color = Color(Theme.accent)
    
    var body: some View {
        Button(action: {
            withAnimation {
                self.isOn.toggle()
            }
        }, label: {
            ZStack {
                SwiftUI.Circle()
                    .strokeBorder(self.color, lineWidth: 3)
                if self.isOn {
                    SwiftUI.Circle()
                        .fill(self.color)
                        .padding(5)
                        .transition(.scale)
                }
            }
        })
    }
}
