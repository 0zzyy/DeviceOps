import Foundation

public enum CommandEvent: Equatable {
    case queued
    case started
    case succeeded
    case failed(reason: String)
}

public struct CommandJobStateMachine {
    public init() {}

    public func transition(current: CommandStatus, event: CommandEvent) -> CommandStatus {
        switch (current, event) {
        case (.queued, .started):
            return .inProgress
        case (.queued, .failed), (.inProgress, .failed):
            return .failed
        case (.inProgress, .succeeded):
            return .succeeded
        default:
            return current
        }
    }
}
