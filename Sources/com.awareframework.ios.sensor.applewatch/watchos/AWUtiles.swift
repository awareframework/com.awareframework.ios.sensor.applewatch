//
//  AWUtiles.swift
//  com.awareframework.ios.sensor.applewatch
//
//  Created by Yuuki Nishiyama on 2025/07/07.
//


import Accelerate
import SoundAnalysis
import DataCompression
import WatchConnectivity

//https://betterprogramming.pub/audio-visualization-in-swift-using-metal-accelerate-part-1-390965c095d7
class SignalProcessing {

//    https://pebble8888.hatenablog.com/entry/2014/06/28/010205
//    https://macasakr.sakura.ne.jp/decibel4.html
    static func rms(data: UnsafeMutablePointer<Float>, frameLength: UInt) -> Float {
        var val : Float = 0
        vDSP_rmsqv(data, 1, &val, frameLength) // 要素の２乗の合計をNで割り平方根を取る
        return val
    }

    static func db(from rms:Float, base:Float=1) -> Float {
        /// 音圧レベルとは、音による気圧の差をデシベルで表示したものです。
        /// この場合、20μPaの音圧（気圧差）を基準値P0（0dB）として、以下の式で求められます。
        /// 音圧レベルLp=10log(P/P0)m2=20log(P/P0)
        return 20*log10f(rms/base)
    }

//    static func fft(data: UnsafeMutablePointer<Float>, setup: OpaquePointer) -> [Float] {
//        //output setup
//        var realIn = [Float](repeating: 0, count: 1024)
//        var imagIn = [Float](repeating: 0, count: 1024)
//        var realOut = [Float](repeating: 0, count: 1024)
//        var imagOut = [Float](repeating: 0, count: 1024)
//
//        //fill in real input part with audio samples
//        for i in 0...1023 {
//            realIn[i] = data[i]
//        }
//
//
//        vDSP_DFT_Execute(setup, &realIn, &imagIn, &realOut, &imagOut)
//        //our results are now inside realOut and imagOut
//
//
//        //package it inside a complex vector representation used in the vDSP framework
//        var complex = DSPSplitComplex(realp: &realOut, imagp: &imagOut)
//
//        //setup magnitude output
//        var magnitudes = [Float](repeating: 0, count: 512)
//
//        //calculate magnitude results
//        vDSP_zvabs(&complex, 1, &magnitudes, 1, 512)
//
//        return magnitudes;
//    }

    /// - Parameter buffer: Audio data in PCM format
    static func fft(_ buffer: AVAudioPCMBuffer) -> [Float] {

        let size: Int = Int(buffer.frameLength)

        /// Set up the transform
        let log2n = UInt(round(log2f(Float(size))))
        let bufferSize = Int(1 << log2n)

        /// Sampling rate / 2
        let inputCount = bufferSize / 2

        /// FFT weights arrays are created by calling vDSP_create_fftsetup (single-precision) or vDSP_create_fftsetupD (double-precision). Before calling a function that processes in the frequency domain
        let fftSetup = vDSP_create_fftsetup(log2n, Int32(kFFTRadix2))

        /// Create the complex split value to hold the output of the transform
        var realp = [Float](repeating: 0, count: inputCount)
        var imagp = [Float](repeating: 0, count: inputCount)
        var output = DSPSplitComplex(realp: &realp, imagp: &imagp)


        var transferBuffer = [Float](repeating: 0, count: bufferSize)
        vDSP_hann_window(&transferBuffer, vDSP_Length(bufferSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul((buffer.floatChannelData?.pointee)!, 1, transferBuffer,
                  1, &transferBuffer, 1, vDSP_Length(bufferSize))

        let temp = UnsafePointer<Float>(transferBuffer)

        temp.withMemoryRebound(to: DSPComplex.self, capacity: transferBuffer.count) { (typeConvertedTransferBuffer) -> Void in
            vDSP_ctoz(typeConvertedTransferBuffer, 2, &output, 1, vDSP_Length(inputCount))
        }
        /// Do the fast Fournier forward transform
        vDSP_fft_zrip(fftSetup!, &output, 1, log2n, Int32(FFT_FORWARD))

        /// Convert the complex output to magnitude
        var magnitudes = [Float](repeating: 0.0, count: inputCount)
        vDSP_zvmags(&output, 1, &magnitudes, 1, vDSP_Length(inputCount))

        var normalizedMagnitudes = [Float](repeating: 0.0, count: inputCount)
        vDSP_vsmul(sqrtq(magnitudes), 1, [2.0/Float(inputCount)],
                   &normalizedMagnitudes, 1, vDSP_Length(inputCount))

//        print("Normalized magnitudes: \(magnitudes)")

        /// Release the setup
         vDSP_destroy_fftsetup(fftSetup)

        return normalizedMagnitudes

    }

    static func sqrtq(_ x: [Float]) -> [Float] {
        var results = [Float](repeating: 0.0, count: x.count)
        vvsqrtf(&results, x, [Int32(x.count)])

        return results
    }

}


public class FileTransferManager {
    
    func transferFile(fileURL:URL, compression:Bool=true, debug:Bool=false) {
    
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                if (FileManager.default.fileExists(atPath: fileURL.path)){
                    // ファイル圧縮を必要とする場合
                    if compression {
                        let d = try Data(contentsOf: fileURL)
                        let compressedFileName = fileURL.lastPathComponent + ".zlib"
                        let docsDirect = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    
                        let compressedFileURL = docsDirect.appendingPathComponent(compressedFileName)
                        try d.compress(withAlgorithm: .zlib)?.write(to: compressedFileURL)
                        
                        if debug {
                            print("\(fileURL.lastPathComponent): \(self.getFileSize(path: fileURL.path)) -> \(self.getFileSize(path: compressedFileURL.path))")
                        }
                        
                        DispatchQueue.main.async {
                            WCSession.default.transferFile(compressedFileURL, metadata: nil)
                        }
                        try FileManager.default.removeItem(at: fileURL)
                    // 既にファイルが圧縮済みの場合
                    }else{
                        if debug {
                            print("\(#function) -> transfer a file \(fileURL.lastPathComponent) without data compression")
                        }
                        DispatchQueue.main.async {
                            WCSession.default.transferFile(fileURL, metadata: nil)
                        }
                    }
                    
                }else{
                    if (debug) {
                        print("file does not exist -> \(fileURL.lastPathComponent)")
                    }
                }
            
            }catch {
                print(error)
            }
        }
    }
    
    private func getFileSize(path:String) -> UInt64 {
        do {
            let manager = FileManager.default
            let attributes = try manager.attributesOfItem(atPath: path) as NSDictionary
            return attributes.fileSize()
        }catch{
            return 0
        }

    }
}

