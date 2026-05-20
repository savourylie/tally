import Foundation
import Observation

enum CollectorState: Sendable, Equatable {
    case idle
    case running
    case failed(String)
}

@MainActor
protocol FlowCollector: AnyObject, Observable {
    var state: CollectorState { get }
    func start()
    func stop()
}
