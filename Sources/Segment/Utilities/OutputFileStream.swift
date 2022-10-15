//
//  OutputFileStream.swift
//  
//
//  Created by Brandon Sneed on 10/15/22.
//

import Foundation

/** C style output filestream ----------------- */

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

struct OutputFileStream {
    enum OutputStreamError: Error {
        case invalidPath(String)
        case unableToOpen(String)
        case unableToWrite
    }
    
    internal var filePointer: UnsafeMutablePointer<FILE>? = nil
    
    init(fileURL: URL) throws {
        let path = fileURL.path
        guard path.isEmpty == false else { throw OutputStreamError.invalidPath(path) }
        
        path.withCString { file in
            filePointer = fopen(file, "w")
        }
        guard filePointer != nil else { throw OutputStreamError.unableToOpen(path) }
    }
    
    func write(_ data: Data) throws {
        guard let string = String(data: data, encoding: .utf8) else { return }
        try write(string)
    }
    
    func write(_ string: String) throws {
        guard string.isEmpty == false else { return }
        _ = try string.utf8.withContiguousStorageIfAvailable { str in
            if let baseAddr = str.baseAddress {
                fwrite(baseAddr, 1, str.count, filePointer)
            } else {
                throw OutputStreamError.unableToWrite
            }
            if ferror(filePointer) != 0 {
                throw OutputStreamError.unableToWrite
            }
        }
    }
    
    func close() {
        fclose(filePointer)
    }
}


/** FileHandle version for comparison ------------------------------------ */
/*
struct OutputFileStream {
    enum OutputStreamError: Error {
        case unableToWrite
        case unableToCreate(String)
    }
    
    internal var fileHandle: FileHandle
    
    init(fileURL: URL) throws {
        let created = FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        if !created { throw OutputStreamError.unableToCreate(fileURL.path) }
        fileHandle = try FileHandle(forWritingTo: fileURL)
    }
    
    func write(_ data: Data) throws {
        fileHandle.seekToEndOfFile()
        if #available(macOS 10.15.4, iOS 13.4, *) {
            try fileHandle.write(contentsOf: data)
        } else {
            fileHandle.write(data)
        }
    }
    
    func write(_ string: String) throws {
        guard let data = string.data(using: .utf8) else { throw OutputStreamError.unableToWrite }
        try write(data)
    }
    
    func close() {
        try? fileHandle.close()
    }
}
*/
