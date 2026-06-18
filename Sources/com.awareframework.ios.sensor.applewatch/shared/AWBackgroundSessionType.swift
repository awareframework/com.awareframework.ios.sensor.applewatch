import Foundation

public enum AWBackgroundSessionType: String, CaseIterable, Identifiable, Hashable {
    case none
    case workout
    case microphone

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .none: return "None"
        case .workout: return "Workout"
        case .microphone: return "Microphone"
        }
    }

    public init(rawValueOrDefault rawValue: String?) {
        guard let rawValue,
              let value = AWBackgroundSessionType(rawValue: rawValue) else {
            self = .microphone
            return
        }
        self = value
    }
}
