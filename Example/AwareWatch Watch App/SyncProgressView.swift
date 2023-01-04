//
//  SyncProgressView.swift
//  com.awareframework.ios.sensor.applewatch_Example Watch App
//
//  Created by Yuuki Nishiyama on 2022/12/27.
//  Copyright © 2022 CocoaPods. All rights reserved.
//

import SwiftUI
import WatchConnectivity

struct SyncProgressView: View {
    
    // Identifiableに準拠したデータ型の定義
    struct FileTransfer: Identifiable {
        var id = UUID()     // ユニークなIDを自動で設定
        var file : WCSessionFileTransfer
    }
    
    @State private var fileTransfers = WCSession.default.outstandingFileTransfers.map { file in
        return FileTransfer(file: file)
    }
    
    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1.0)) { context in
            List {
                ForEach(fileTransfers) { transfer in
                    VStack {
                        Text(transfer.file.file.fileURL.lastPathComponent)
                        ProgressView(value: transfer.file.progress.fractionCompleted)
                        HStack {
                            if (transfer.file.progress.isPaused) {
                                Text("\(transfer.file.progress.isPaused ? "中断" : "" )")
                            }
                            if (transfer.file.progress.isFinished) {
                                Text("\(transfer.file.progress.isFinished ? "完了" : "" )")
                            }
                            if (transfer.file.progress.isCancelled) {
                                Text("\(transfer.file.progress.isCancelled ? "キャンセル" : "" )")
                            }
                        }
                    }
                }
                Button("全てキャンセル") {
                    fileTransfers.forEach { transfer in
                        transfer.file.cancel()
                    }
                }
            }
        }
    }
}

struct ProgressView_Previews: PreviewProvider {
    static var previews: some View {
        ProgressView()
    }
}
