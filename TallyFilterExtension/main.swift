import Dispatch
import NetworkExtension
import os

private let log = Logger(subsystem: "app.tally", category: "filter-extension")

private func main() -> Never {
    autoreleasepool {
        log.debug("[filter] first light")
        NEProvider.startSystemExtensionMode()
    }
    dispatchMain()
}

main()
