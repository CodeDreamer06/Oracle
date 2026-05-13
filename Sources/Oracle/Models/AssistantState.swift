import Foundation

enum AssistantState: Equatable {
    case idle
    case listening(volume: Double)
    case transcribing
    case thinking
    case speaking
    case toolExecuting(name: String)
}

struct OracleError: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}
