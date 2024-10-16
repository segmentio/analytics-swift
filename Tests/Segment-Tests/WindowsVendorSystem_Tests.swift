import XCTest
@testable import Segment

#if os(Windows)

final class WindowsVendorSystem_Tests: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        Telemetry.shared.enable = false
    }

    func testScreenSizeReturnsNonEmpty() {
        let system = WindowsVendorSystem()

        let screen = system.screenSize

        XCTAssertNotEqual(screen.width, 0)
        XCTAssertNotEqual(screen.height, 0)
    }

    func testNameReturnsNonEmpty() {
        let system = WindowsVendorSystem()

        let name = system.systemName

        XCTAssertNotEqual(name, "unknown")
    }

    func testVersionNumberIsWellFormatted() {
        let system = WindowsVendorSystem()

        let version = system.systemVersion

        let components = version.split(separator: ".")

        XCTAssertEqual(components.count, 3)

        // Ensure that the version components are all numeric
        XCTAssertTrue(components.allSatisfy({ Int($0) != nil }))
    }
}

#endif
