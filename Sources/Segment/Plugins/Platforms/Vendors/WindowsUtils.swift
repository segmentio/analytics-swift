import Foundation

#if os(Windows)

import WinSDK

internal class WindowsVendorSystem: VendorSystem {
    override var manufacturer: String {
        return "unknown"
    }

    override var type: String {
        return "Windows"
    }

    override var model: String {
        return "unknown"
    }

    override var name: String {
        return "unknown"
    }

    override var identifierForVendor: String? {
        return nil
    }

    override var systemName: String {
        // If the name is larger than 256 characters, we might get an error.
        var size: DWORD = 256
        var buffer = [CHAR](repeating: 0, count: Int(size))
        guard GetComputerNameA(&buffer, &size) else {
            return "unknown"
        }

        return String(cString: buffer)
    }

    override var systemVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    override var screenSize: ScreenSize {
        var rect: RECT = .init(left: 0, top: 0, right: 0, bottom: 0)
        guard SystemParametersInfoA(UInt32(SPI_GETWORKAREA), 0, &rect, 0) else {
            return ScreenSize(width: 0, height: 0)
        }

        return ScreenSize(width: rect.width, height: rect.height)
    }

    override var userAgent: String? {
        return "unknown"
    }

    override var connection: ConnectionStatus {
        return .unknown
    }

    override var requiredPlugins: [any PlatformPlugin] {
        []
    }
}

extension RECT {
    internal var width: Double {
        Double(right - left)
    }

    internal var height: Double {
        Double(bottom - top)
    }
}
#endif
