import Agentic
import AgenticHYAI
import AgenticModels
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

        guard let profile = profiles.first(
            where: { $0.identifier == .hyai_auto }
        ) else {
            throw HYAIAvailabilityFixtureError
                .expectedAutoProfile
        }

        try Expect.equal(
            profile.identifier,
            .hyai_auto,
            "HostYourAI retains an explicitly addressable virtual auto profile"
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

    static func runHYAIExplicitModelProfileSemantics()
        async throws
        -> [TestDiagnostic]
    {
        let profiles = try HYAIModelProfileProvider().profiles()
        let catalog = try ProfileCatalog(
            profiles: profiles
        )

        let matchingProfiles = catalog.profiles(
            for: KnownModel.glm.v5_3_flash
        )

        try Expect.equal(
            matchingProfiles.count,
            1,
            "HostYourAI contributes exactly one profile for canonical GLM 5.3 Flash"
        )

        let selection = AgentModelSelection.exactModel(
            KnownModel.glm.v5_3_flash,
            through: .hyai
        )

        let result = try StaticModelRouter().route(
            .init(
                selection: selection
            ),
            catalog: catalog
        )

        try Expect.equal(
            result.route.profile.identifier,
            .hyai_glm_v5_3_flash,
            "exact GLM selection resolves to the concrete HostYourAI profile"
        )
        try Expect.equal(
            result.route.profile.modelID,
            KnownModel.glm.v5_3_flash,
            "resolved HostYourAI profile retains the canonical model identity"
        )
        try Expect.equal(
            result.route.profile.model,
            "zai-org/GLM-5.3-Flash",
            "resolved HostYourAI profile retains the gateway-native physical model identifier"
        )
        try Expect.equal(
            result.route.profile.gateway.id,
            .hyai,
            "resolved physical model routes through the HostYourAI gateway"
        )

        let autoProfiles = profiles.filter {
            $0.identifier == .hyai_auto
        }
        let autoOnlyCatalog = try ProfileCatalog(
            profiles: autoProfiles
        )

        do {
            _ = try StaticModelRouter().route(
                .init(
                    selection: selection
                ),
                catalog: autoOnlyCatalog
            )

            throw HYAIAvailabilityFixtureError
                .expectedFailClosedRouting
        } catch AgentModelRoutingError.noRoute(let purpose) {
            try Expect.equal(
                purpose,
                .executor,
                "exact physical model selection fails closed when the physical profile is unavailable"
            )
        }

        return [
            .field(
                "canonical_model",
                KnownModel.glm.v5_3_flash.rawValue
            ),
            .field(
                "profile",
                result.route.profile.identifier.rawValue
            ),
            .field(
                "wire_model",
                result.route.profile.model
            ),
        ]
    }
}

private enum HYAIAvailabilityFixtureError:
    Error
{
    case missingFactory
    case expectedUnavailable
    case expectedAutoProfile
    case expectedFailClosedRouting
}
