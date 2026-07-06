import Foundation
import RelayDogCore

struct RelayDogUpstreamEditorDraft {
    var id: String
    var name: String
    var enabled: Bool
    var weightText: String
    var timeoutSecondsText: String
    var note: String
    var openAI: ProtocolCapabilityConfig
    var claude: ProtocolCapabilityConfig

    init(upstream: UpstreamConfig?) {
        id = upstream?.id ?? UUID().uuidString
        name = upstream?.name ?? ""
        enabled = upstream?.enabled ?? true
        weightText = "\(upstream?.weight ?? 100)"
        timeoutSecondsText = "\(upstream?.timeoutSeconds ?? 60)"
        note = upstream?.note ?? ""
        openAI = upstream?.protocols[.openAI] ?? Self.defaultCapability(for: .openAI, enabled: upstream == nil)
        claude = upstream?.protocols[.claude] ?? Self.defaultCapability(for: .claude, enabled: false)
    }

    init(
        id: String,
        name: String,
        enabled: Bool,
        weightText: String,
        timeoutSecondsText: String,
        note: String,
        openAI: ProtocolCapabilityConfig,
        claude: ProtocolCapabilityConfig
    ) {
        self.id = id
        self.name = name
        self.enabled = enabled
        self.weightText = weightText
        self.timeoutSecondsText = timeoutSecondsText
        self.note = note
        self.openAI = openAI
        self.claude = claude
    }

    func makeUpstream() -> UpstreamConfig {
        UpstreamConfig(
            id: id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            enabled: enabled,
            weight: max(1, Int(weightText) ?? 100),
            timeoutSeconds: max(1, Int(timeoutSecondsText) ?? 60),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            protocols: [
                .openAI: openAI,
                .claude: claude
            ]
        )
    }

    private static func defaultCapability(for proto: ProxyProtocol, enabled: Bool) -> ProtocolCapabilityConfig {
        ProtocolCapabilityConfig(
            enabled: enabled,
            baseURL: proto == .openAI ? "https://api.example.com/v1" : "https://api.example.com",
            apiKey: "",
            headerOverrides: [:],
            healthCheckPath: "/v1/models",
            modelSync: .manual,
            models: [],
            modelMappings: [:]
        )
    }
}
