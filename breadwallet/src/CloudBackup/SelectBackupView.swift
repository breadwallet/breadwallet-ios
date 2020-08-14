// 
//  SelectBackupView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2020-07-30.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import SwiftUI

enum SelectBackupError: Error {
    case didCancel
}

@available(iOS 13.6, *)
typealias SelectBackupResult = Result<CloudBackup, Error>

@available(iOS 13.6, *)
struct SelectBackupView: View {
    
    let backups: [CloudBackup]
    let callback: (SelectBackupResult) -> Void
    @SwiftUI.State private var selectedBackup: CloudBackup?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(Theme.primaryBackground))
            VStack {
                Text(S.CloudBackup.selectTitle)
                    .foregroundColor(Color(Theme.primaryText))
                    .lineLimit(nil)
                    .font(Font(Theme.h2Title))
                ForEach(0..<backups.count) { i in
                    BackupCell(backup: self.backups[i],
                               isOn: self.binding(for: i))
                    .padding(4.0)
                }
                self.okButton()
            }
        }.edgesIgnoringSafeArea(.all)
        .navigationBarItems(trailing: EmptyView())
    }
    
    private func okButton() -> some View {
        Button(action: {
            self.callback(.success(self.selectedBackup!))
        }, label: {
            ZStack {
                RoundedRectangle(cornerRadius: 4.0)
                    .fill(Color(UIColor.primaryButton))
                    .opacity(self.selectedBackup == nil ? 0.3 : 1.0)
                Text(S.Button.continueAction)
                    .foregroundColor(Color(Theme.primaryText))
                    .font(Font(Theme.h3Title))
            }
        })
        .frame(height: 44.0)
        .cornerRadius(4.0)
        .disabled(self.selectedBackup == nil)
        .padding(EdgeInsets(top: 8.0, leading: 32.0, bottom: 32.0, trailing: 32.0))
    }
    
    private func binding(for index: Int) -> Binding<Bool> {
        Binding<Bool>(
            get: {
                guard let selectedBackup = self.selectedBackup else { return false }
                return self.backups[index].identifier == selectedBackup.identifier },
            set: { if $0 { self.selectedBackup = self.backups[index] } }
        )
    }
}

@available(iOS 13.6, *)
struct BackupCell: View {
    
    let backup: CloudBackup
    @SwiftUI.Binding var isOn: Bool
    
    private let gradient = Gradient(colors: [Color(UIColor.gradientStart), Color(UIColor.gradientEnd)])
    
    var body: some View {
        HStack {
            RadioButton(isOn: $isOn)
                .frame(width: 44.0, height: 44.0)
            VStack(alignment: .leading) {
                Text(dateString)
                    .foregroundColor(Color(Theme.primaryText))
                    .font(Font(Theme.body1))
                    .padding(EdgeInsets(top: 8.0, leading: 8.0, bottom: 0.0, trailing: 8.0))
                Text("\(backup.deviceName)")
                    .foregroundColor(Color(Theme.secondaryText))
                    .font(Font(Theme.body1))
                    .padding(EdgeInsets(top: 0.0, leading: 8.0, bottom: 8.0, trailing: 8.0))
            }
        }
    }
    
    var dateString: String {
        let df = DateFormatter()
        df.dateFormat = "MMM d yyyy HH:mm:ss"
        return "\(df.string(from: backup.createTime))"
    }
}

@available(iOS 13.6, *)
struct RestoreCloudBackupView_Previews: PreviewProvider {
    static var previews: some View {
        SelectBackupView(backups: [
            CloudBackup(phrase: "this is a phrase", identifier: "key", pin: "12345"),
            CloudBackup(phrase: "this is another phrase", identifier: "key", pin: "12345"),
            CloudBackup(phrase: "this is yet another phrase", identifier: "key", pin: "12345")
        ], callback: {_ in })
    }
}
