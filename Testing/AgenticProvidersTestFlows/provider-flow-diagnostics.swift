import Agentic
import TestFlows

enum ProviderFlowDiagnostics {
    static func input(
        _ request: AgentRequest
    ) -> TestDiagnostic {
        .section(
            "input",
            requestLines(
                request
            )
        )
    }

    static func output(
        _ response: AgentResponse
    ) -> TestDiagnostic {
        .section(
            "output",
            responseLines(
                response
            )
        )
    }

    static func stream(
        _ events: [AgentStreamEvent]
    ) -> TestDiagnostic {
        .section(
            "stream",
            streamLines(
                events
            )
        )
    }

}
private extension ProviderFlowDiagnostics {
    static func requestLines(
        _ request: AgentRequest
    ) -> [String] {
        var lines: [String] = [
            "tools: \(request.tools.map(\.name).joined(separator: ", "))"
        ]

        for message in request.messages {
            lines.append(
                "\(message.role.rawValue): \(message.content.text)"
            )
        }

        return lines
    }

    static func responseLines(
        _ response: AgentResponse
    ) -> [String] {
        [
            "role: \(response.message.role.rawValue)",
            "stopReason: \(response.stopReason.rawValue)",
            "text: \(response.message.content.text)",
            "metadata: \(response.metadata)"
        ]
    }

    static func streamLines(
        _ events: [AgentStreamEvent]
    ) -> [String] {
        events.map { event in
            switch event {
            case .messagedelta(let block):
                return "delta: \(block)"

            case .toolcall(let call):
                return "toolcall: \(call.tool.rawValue) id=\(call.id) input=\(call.input)"

            case .toolresult(let result):
                return "toolresult: \(result.tool?.rawValue ?? "<nil>") id=\(result.toolCallID) output=\(result.output)"

            case .completed(let response):
                return "completed: \(response.message.content.text)"
            }
        }
    }
}
