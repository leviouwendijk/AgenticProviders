import Agentic
import AgenticHYAI
import Foundation
import TestFlows

extension AgenticProvidersFlowTesting {
    static func runHYAIMissingConfigurationAvailability()
        async throws
        -> [TestDiagnostic]
    {
        let symbol =
            "AGENTIC_TEST_MISSING_HYAI_KEY_\(UUID().uuidString)"
        let provider = HYAIModelProvider(
            apiKeySymbol: symbol
        )

        guard let factory =
            provider.gateways.first
        else {
            throw HYAIAvailabilityFixtureError
                .missingFactory
        }

        guard case .unavailable(let reason) =
            try await factory.resolve()
        else {
            throw HYAIAvailabilityFixtureError
                .expectedUnavailable
        }

        try Expect.equal(
            reason.kind,
            .missing_configuration,
            "missing HostYourAI API key resolves as typed gateway unavailability"
        )
        try Expect.equal(
            reason.metadata["symbol"],
            symbol,
            "HostYourAI unavailability retains the missing environment symbol"
        )
        try Expect.equal(
            reason.metadata["state"],
            "missing",
            "HostYourAI unavailability distinguishes missing configuration"
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
                reason.metadata["state"]
                    ?? "<none>"
            ),
        ]
    }

    static func runHYAIAutoProfileSemantics()
        async throws
        -> [TestDiagnostic]
    {
        let profiles = try HYAIModelProfileProvider(
            autoPolicy: .quality
        ).profiles()

        guard profiles.count == 1,
              let profile = profiles.first
        else {
            throw HYAIAvailabilityFixtureError
                .expectedOneProfile
        }

        try Expect.equal(
            profile.identifier,
            .hyai_auto,
            "HostYourAI contributes one virtual auto profile"
        )
        try Expect.equal(
            profile.gateway.id,
            .hyai,
            "HostYourAI auto profile routes through the HYAI gateway"
        )
        try Expect.equal(
            profile.model,
            "hyai/auto",
            "HostYourAI auto profile delegates physical model selection to HostYourAI"
        )
        try Expect.equal(
            profile.privacy,
            .private_cloud,
            "HostYourAI shared inference is external private-cloud inference"
        )
        try Expect.equal(
            profile.capabilities.contains(
                .tool_use
            ),
            true,
            "HostYourAI auto profile advertises proven tool use"
        )
        try Expect.equal(
            profile.capabilities.contains(
                .streaming
            ),
            true,
            "HostYourAI auto profile advertises streaming"
        )
        try Expect.equal(
            profile.capabilities.contains(
                .structured_output
            ),
            false,
            "HostYourAI auto profile does not advertise unproven structured output"
        )
        try Expect.equal(
            profile.capabilities.contains(
                .reasoning
            ),
            false,
            "HostYourAI auto profile does not assign fixed reasoning semantics to a dynamically routed model"
        )
        try Expect.equal(
            profile.purposes.contains(
                .local_private
            ),
            false,
            "HostYourAI auto profile is not eligible for local-private routing"
        )
        try Expect.equal(
            profile.metadata["auto_policy"],
            "quality",
            "HostYourAI auto policy is retained in profile metadata"
        )

        return [
            .field(
                "profile",
                profile.identifier.rawValue
            ),
            .field(
                "model",
                profile.model
            ),
            .field(
                "gateway",
                profile.gateway.id.rawValue
            ),
            .field(
                "auto_policy",
                profile.metadata["auto_policy"]
                    ?? "<none>"
            ),
        ]
    }
}

private enum HYAIAvailabilityFixtureError:
    Error
{
    case missingFactory
    case expectedUnavailable
    case expectedOneProfile
}
