//
//  AWCompression.swift
//  com.awareframework.ios.sensor.applewatch
//
//  Compresses the files the watch sends to the iPhone, with Apple's Compression framework
//  (through Foundation's NSData API).
//
//  Format: zlib's raw deflate stream (RFC 1951), with no header or checksum. It is the same
//  format DataCompression's `compress(withAlgorithm: .zlib)` wrote up to 1.7.0, so a watch and an
//  iPhone on different library versions still read each other's files.
//

import Foundation

public enum AWCompression {

    /// Compresses `data` into a raw deflate stream. Throws when the system cannot compress it.
    public static func compress(_ data: Data) throws -> Data {
        try (data as NSData).compressed(using: .zlib) as Data
    }

    /// Restores data compressed by `compress(_:)` (or by the library up to 1.7.0).
    /// Throws when `data` is not a valid raw deflate stream.
    public static func decompress(_ data: Data) throws -> Data {
        try (data as NSData).decompressed(using: .zlib) as Data
    }
}
