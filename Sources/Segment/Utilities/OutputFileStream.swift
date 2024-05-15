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
#elseif os(Windows)
import WinSDK
#else
import Darwin.C
#endif

internal class OutputFileStream {
    enum OutputStreamError: Error {
        case invalidPath(String)
        case unableToOpen(String)
        case unableToWrite(String)
        case unableToCreate(String)
        case unableToClose(String)
    }

    var fileHandle: FileHandle? = nil
    let fileURL: URL

    init(fileURL: URL) throws {
        self.fileURL = fileURL
        let path = fileURL.path
        guard path.isEmpty == false else { throw OutputStreamError.invalidPath(path) }
    }

    /// Create attempts to create + open
    func create() throws {
        let path = fileURL.path
        if FileManager.default.fileExists(atPath: path) {
            throw OutputStreamError.unableToCreate(path)
        } else {
            let created = FileManager.default.createFile(atPath: fileURL.path, contents: nil)
            if created == false {
                throw OutputStreamError.unableToCreate(path)
            } else {
                try open()
            }
        }
    }

    /// Open simply opens the file, no attempt at creation is made.
    func open() throws {
        if fileHandle != nil { return }
        do {
            fileHandle = try FileHandle(forWritingTo: fileURL)
            if #available(iOS 13.4, macOS 10.15.4, tvOS 13.4, *) {
                _ = try? fileHandle?.seekToEnd()
            } else if #available(tvOS 13.0, *) {
                try? fileHandle?.seek(toOffset: .max)
            } else {
                // unsupported
                throw OutputStreamError.unableToOpen(fileURL.path)
            }
        } catch {
            throw OutputStreamError.unableToOpen(fileURL.path)
        }
    }

    func write(_ data: Data) throws {
        guard data.isEmpty == false else { return }
        if #available(macOS 10.15.4, iOS 13.4, macCatalyst 13.4, tvOS 13.4, watchOS 13.4, *) {
            do {
                try fileHandle?.write(contentsOf: data)
            } catch {
                throw OutputStreamError.unableToWrite(fileURL.path)
            }
        } else {
            // Fallback on earlier versions
            fileHandle?.write(data)
        }
    }

    func write(_ string: String) throws {
        guard string.isEmpty == false else { return }
        if let data = string.data(using: .utf8) {
            try write(data)
        }
    }

    func close() throws {
        do {
            let existing = fileHandle
            fileHandle = nil
            if #available(tvOS 13.0, *) {
                try existing?.synchronize() // this might be overkill, but JIC.
                try existing?.close()
            } else {
                // Fallback on earlier versions
                existing?.synchronizeFile()
                existing?.closeFile()
            }
        } catch {
            throw OutputStreamError.unableToClose(fileURL.path)
        }
    }
}
