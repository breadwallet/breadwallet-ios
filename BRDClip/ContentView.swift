// 
//  ContentView.swift
//  BRDClip
//
//  Created by Adrian Corscadden on 2020-11-19.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("Welcome to the BRD app Clip")
            .padding()
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb, perform: { activity in
                print("continued activity: \(activity.webpageURL)")
            })
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
