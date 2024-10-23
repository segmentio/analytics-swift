//
//  CompletionGroup_Tests.swift
//  
//
//  Created by Brandon Sneed on 4/17/24.
//

import XCTest
@testable import Segment

final class CompletionGroup_Tests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        Telemetry.shared.enable = false
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    /*func testCompletionGroup() throws {
        defer {
            RunLoop.main.run()
        }
        
        //let flushQueue = DispatchQueue(label: "com.segment.flush")
        let flushQueue = DispatchQueue(label: "com.segment.flush", attributes: .concurrent)
        
        let group = CompletionGroup(queue: flushQueue)
        
        group.add { group in
            group.enter()
            print("item1 - sleeping 10")
            sleep(10)
            print("item1 - done sleeping")
            group.leave()
        }
        
        group.add { group in
            group.enter()
            print("item2 - launching an async task")
            DispatchQueue.global(qos: .background).async {
                print("item2 - background, sleeping 5")
                sleep(5)
                print("item2 - background, done sleeping")
                group.leave()
            }
        }
        
        group.add { group in
            group.enter()
            print("item3 - returning real quick")
            group.leave()
        }
        
        group.add { group in
            print("item4 - not entering group")
        }
        
        group.run(mode: .asynchronous) {
            print("all items completed.")
        }
        
        print("test exited.")
    }*/

}
