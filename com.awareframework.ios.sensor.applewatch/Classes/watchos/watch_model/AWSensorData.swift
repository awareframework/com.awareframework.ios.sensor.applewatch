//
//  AWSensorData.swift
//  com.awareframework.ios.sensor.applewatch-watchOS
//
//  Created by Yuuki Nishiyama on 2022/12/17.
//

#if os(iOS)


#elseif os(watchOS)

import Foundation
import CoreMotion

public class AWSensorData:NSObject{

    public let filePath:URL
    let fileManager = FileManager()
    var fileHandle:FileHandle? = nil
    public let header:[String]

    var lastUpdate = Date()

    public init(_ dataType:String, header:[String]) {
        // create a file
        let timestamp = Int(Date().timeIntervalSince1970)
        let docsDirect = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        filePath = docsDirect.appendingPathComponent("\(dataType)_\(timestamp).csv")
        
        // add header
        do {
            self.header = header
            let headerLine = header.reduce("") { partialResult, h in
                if (partialResult == "") {
                    return h
                }
                return partialResult + "," + h
            }
            // print(headerLine)
            try (headerLine+"\n").write(to: filePath, atomically: true, encoding: .utf8 )
        } catch {
            print("\(error)")
        }
        
        super.init()
    }

    public func save(_ values:[String]){
        if let uwFileHandle = fileHandle {
            if (self.header.count == values.count) {
                uwFileHandle.seekToEndOfFile()
                let line = values.reduce("") { partialResult, v in
                    if (partialResult == "") {
                        return v
                    }
                    return partialResult + "," + v
                }
                uwFileHandle.write("\(line)\n".data(using: String.Encoding.utf8)!)
                self.lastUpdate = Date()
            }else{
                print("[Error] The provided values and number of headers are different : \(#function)")
            }
        }
    }
    

    public func openFileHandler(){
        do {
            if (fileHandle == nil) {
                fileHandle = try FileHandle(forWritingTo: self.filePath)
            }
        } catch {
            print("\(error)")
        }
    }

    public func closeFileHandler(){
        if let uwFileHandle = fileHandle {
            uwFileHandle.closeFile()
        }
        fileHandle = nil
    }

}

#endif
