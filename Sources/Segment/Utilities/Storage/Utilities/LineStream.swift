//
//  File.swift
//  
//
//  Created by Brandon Sneed on 11/30/23.
//

import Foundation

internal struct LineStreamConstants {
    static let delimiter = "\n".data(using: .utf8)!
}

internal class LineStreamReader {
    let fileHandle: FileHandle
    let bufferSize: Int
    var eof = false
    
    var buffer: Data
    
    init?(url: URL, bufferSize: Int = 4096)
    {
        guard let validURL = try? FileHandle.createIfNecessary(url: url) else { return nil }
        guard let fileHandle = try? FileHandle(forReadingFrom: validURL) else { return nil }
        self.fileHandle = fileHandle
        self.bufferSize = bufferSize
        self.buffer = Data(capacity: bufferSize)
    }
    
    deinit {
        fileHandle.closeFile()
    }
    
    func reset() {
        fileHandle.seek(toFileOffset: 0)
        buffer.removeAll(keepingCapacity: true)
        eof = false
    }
    
    func readLine() -> String? {
        if eof { return nil }
        
        repeat {
            if let range = buffer.range(of: LineStreamConstants.delimiter, options: [], in: buffer.startIndex..<buffer.endIndex) {
                let subData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
                let line = String(data: subData, encoding: .utf8)
                buffer.replaceSubrange(buffer.startIndex..<range.upperBound, with: [])
                return line
            } else {
                let tempData = fileHandle.readData(ofLength: bufferSize)
                if tempData.count == 0 {
                    eof = true
                    return (buffer.count > 0) ? String(data: buffer, encoding: .utf8) : nil
                }
                buffer.append(tempData)
            }
        } while true
    }
}

class LineStreamWriter {
    let fileHandle: FileHandle
    let url: URL
    var bytesWritten: UInt64 = 0
    
    init?(url: URL)
    {
        self.url = url
        guard let validURL = try? FileHandle.createIfNecessary(url: url) else { return nil }
        guard let fileHandle = try? FileHandle(forUpdating: validURL) else { return nil }
        self.fileHandle = fileHandle
        
        reset()
    }
    
    deinit {
        if #available(tvOS 13.0, *) {
            _ = try? fileHandle.synchronize() // this might be overkill, but JIC.
            _ = try? fileHandle.close()
        } else {
            // Fallback on earlier versions
            fileHandle.synchronizeFile()
            fileHandle.closeFile()
        }
    }
    
    func reset() {
        if #available(iOS 13.4, macOS 10.15.4, tvOS 13.4, *) {
            _ = try? fileHandle.seekToEnd()
        } else if #available(tvOS 13.0, *) {
            try? fileHandle.seek(toOffset: .max)
        }
        
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) {
            guard let size = attrs[FileAttributeKey.size] as? Int else {
                #if DEBUG
                assertionFailure("Unable to get the size of \(url)")
                #endif
                return
            }
            self.bytesWritten = UInt64(size)
        }
    }
    
    func writeLine(_ str: String) throws {
        var data = str.data(using: .utf8)
        data?.append(LineStreamConstants.delimiter)
        guard let data else { return }
        if #available(macOS 10.15.4, iOS 13.4, macCatalyst 13.4, tvOS 13.4, watchOS 13.4, *) {
            do {
                try fileHandle.write(contentsOf: data)
                self.bytesWritten += UInt64(data.count)
            } catch {
                throw error
            }
        } else {
            // Fallback on earlier versions
            fileHandle.write(data)
            self.bytesWritten += UInt64(data.count)
        }
    }
}
