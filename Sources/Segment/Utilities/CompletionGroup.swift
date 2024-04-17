//
//  CompletionGroup.swift
//
//
//  Created by Brandon Sneed on 4/17/24.
//

import Foundation

class CompletionGroup {
    let queue: DispatchQueue
    var items = [(DispatchGroup) -> Void]()
    
    init(queue: DispatchQueue) {
        self.queue = queue
    }
    
    func add(workItem: @escaping (DispatchGroup) -> Void) {
        items.append(workItem)
    }
    
    func run(mode: OperatingMode, completion: @escaping () -> Void) {
        // capture self strongly on purpose
        let task: () -> Void = { [self] in
            let group = DispatchGroup()
            group.enter()
            group.notify(queue: queue) { [weak self] in
                completion()
                self?.items.removeAll()
            }
            
            for item in items {
                item(group)
            }
            
            group.leave()
            
            if mode == .synchronous {
                group.wait()
            }
        }
        
        switch mode {
        case .synchronous:
            queue.sync {
                task()
            }
        case .asynchronous:
            queue.async {
                task()
            }
        }
    }
}
