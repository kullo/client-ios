import Firebase

extension MessagingAPNSTokenType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .prod: return "prod"
        case .sandbox: return "sandbox"
        case .unknown: return "unknown"
        }
    }
}
