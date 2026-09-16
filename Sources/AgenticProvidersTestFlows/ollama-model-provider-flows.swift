import Agentic
import AgenticOllama
import Foundation
import TestFlows

extension AgenticProvidersFlowTesting {
    static func runOllamaMissingConfigurationAvailability()
        async throws
        -> [TestFlowDiagnostic]
    {
        let symbol =
            "AGENTIC_TEST_MISSING_OLLAMA_ENDPOINT_\(UUID().uuidString)"
        let provider = OllamaModelProvider(
            endpointSymbol: symbol
        )

        guard let factory = provider.gateways.first else {
            throw OllamaAvailabilityFixtureError.missingFactory
        }

        guard case .unavailable(let reason) =
            try await factory.resolve()
        else {
            throw OllamaAvailabilityFixtureError.expectedUnavailable
        }

        try Expect.equal(
            reason.kind,
            .missing_configuration,
            "missing Ollama endpoint configuration resolves as typed gateway unavailability"
        )
        try Expect.equal(
            reason.metadata["symbol"],
            symbol,
            "Ollama unavailability retains the missing environment symbol"
        )
        try Expect.equal(
            reason.metadata["state"],
            "missing",
            "Ollama unavailability distinguishes missing configuration"
        )

        return [
            .field(
                "gateway",
                factory.identifier.rawValue
            ),
            .field(
                "unavailability_kind",
                reason.kind.rawValue
            ),
            .field(
                "configuration_state",
                reason.metadata["state"] ?? "<none>"
            ),
        ]
    }
}

private enum OllamaAvailabilityFixtureError:
    Error
{
    case missingFactory
    case expectedUnavailable
}
