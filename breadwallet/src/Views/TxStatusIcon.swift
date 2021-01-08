// 
//  TxStatusIcon.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2020-09-10.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import SwiftUI

enum StatusIcon {
    case sent
    case received
    case pending(CGFloat) //progress associated value
    case failed
    
    var icon: String {
        switch self {
        case .sent: return "sendArrow"
        case .received: return "receivedArrow"
        case .pending(_): return "pendingIndicator"
        case .failed: return "failed"
        }
    }
    
    @available(iOS 13.0, *)
    var color: Color {
        switch self {
        case .sent:
            return Color(UIColor.fromHex("EFEFF2"))
        case .received:
            return Color(Theme.success).opacity(0.16)
        case .pending(_):
            return Color(Theme.accent).opacity(0.16)
        case .failed:
            return Color(Theme.error).opacity(0.16)
        }
    }
}

@available(iOS 13.0, *)
struct TxStatusIcon: View {
    
    let status: StatusIcon
    
    var body: some View {
        ZStack {
            SwiftUI.Circle()
                .fill(status.color)
            buildBody()
        }.frame(width: 40, height: 40)
    }
    
    func buildBody() -> some View {
        if case .pending(let progress) = status {
            return AnyView(PendingCircle(progress: progress)
                            .padding(10.0))
        } else {
           return AnyView(Image(status.icon))
        }
    }
    
}

@available(iOS 13.0, *)
struct PendingCircle: View {
    
    let progress: CGFloat
    
    var body: some View {
        ZStack {
            SwiftUI.Circle()
                .stroke(lineWidth: 3.0)
                .opacity(0.3)
                .foregroundColor(Color(Theme.accent).opacity(0.30))
            SwiftUI.Circle()
                .trim(from: 0.0, to: progress)
                .stroke(style: StrokeStyle(lineWidth: 3.0, lineCap: .round, lineJoin: .round))
                .foregroundColor(Color(Theme.accent))
                .rotationEffect(Angle(degrees: -90))
            
        }
    }
}

@available(iOS 13.0, *)
struct TxStatusIcon_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            TxStatusIcon(status: .sent)
            TxStatusIcon(status: .received)
            TxStatusIcon(status: .pending(0.0))
            TxStatusIcon(status: .pending(0.25))
            TxStatusIcon(status: .pending(0.5))
            TxStatusIcon(status: .pending(0.75))
            TxStatusIcon(status: .pending(1.0))
            TxStatusIcon(status: .failed)
        }
    }
}
