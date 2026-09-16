import TestFlows

enum AgenticProvidersFlowSuite: TestFlowRegistry {
    static let title = "AgenticProviders flow tests"

    static let flows: [TestFlow] = [
        TestFlow(
            ID.apple_prompt_rendering,
            tags: ["apple", "foundation-models", "offline"]
        ) {
            try await AgenticProvidersFlowTesting.runApplePromptRendering()
        },
        TestFlow(
            ID.apple_tool_bridge,
            tags: ["apple", "foundation-models", "tool-use", "offline"]
        ) {
            try await AgenticProvidersFlowTesting.runAppleToolBridge()
        },
        TestFlow(
            ID.apple_structured_output_lowering,
            tags: ["apple", "foundation-models", "structured-output", "offline"]
        ) {
            try await AgenticProvidersFlowTesting.runAppleStructuredOutputLowering()
        },
        TestFlow(
            ID.apple_model_provider_catalog_realization,
            tags: ["apple", "foundation-models", "model-provider", "model-routing", "offline"]
        ) {
            try await AgenticProvidersFlowTesting.runAppleModelProviderCatalogRealization()
        },
        TestFlow(
            ID.ollama_missing_configuration_availability,
            tags: ["ollama", "model-provider", "gateway", "availability", "offline"]
        ) {
            try await AgenticProvidersFlowTesting.runOllamaMissingConfigurationAvailability()
        },
        TestFlow(
            ID.bedrock_model_provider_catalog_realization,
            tags: ["aws", "bedrock", "model-provider", "model-routing", "offline"]
        ) {
            try await AgenticProvidersFlowTesting.runBedrockModelProviderCatalogRealization()
        },
        TestFlow(
            ID.bedrock_multiple_gateway_provider_realization,
            tags: ["aws", "bedrock", "model-provider", "gateway", "multiple-gateways", "offline"]
        ) {
            try await AgenticProvidersFlowTesting.runBedrockMultipleGatewayProviderRealization()
        },
        TestFlow(
            ID.bedrock_buffered_stream_completion,
            tags: ["aws", "bedrock", "offline", "stream"]
        ) {
            try await AgenticProvidersFlowTesting.runBedrockBufferedStreamCompletion()
        },
        TestFlow(
            ID.bedrock_tool_use_stream,
            tags: ["aws", "bedrock", "offline", "tool-use", "stream"]
        ) {
            try await AgenticProvidersFlowTesting.runBedrockToolUseStream()
        },
        TestFlow(
            ID.bedrock_tool_result_mapping,
            tags: ["aws", "bedrock", "offline", "tool-use"]
        ) {
            try await AgenticProvidersFlowTesting.runBedrockToolResultMapping()
        },
        TestFlow(
            ID.bedrock_model_handle_profile_synthesis,
            tags: ["aws", "bedrock", "model-discovery", "model-routing", "offline"]
        ) {
            try await AgenticProvidersFlowTesting.runBedrockModelHandleProfileSynthesis()
        },
        TestFlow(
            ID.bedrock_non_streaming_handle_drops_streaming_capability,
            tags: ["aws", "bedrock", "model-discovery", "model-routing", "offline"]
        ) {
            try await AgenticProvidersFlowTesting.runBedrockNonStreamingHandleDropsStreamingCapability()
        },
        TestFlow(
            ID.bedrock_generic_snapshot_provider_catalog,
            tags: ["aws", "bedrock", "model-discovery", "model-routing", "offline"]
        ) {
            try await AgenticProvidersFlowTesting.runBedrockGenericSnapshotProviderCatalog()
        },
        TestFlow(
            ID.bedrock_discovery_tool_registration,
            tags: ["aws", "bedrock", "model-discovery", "tools", "offline"]
        ) {
            try await AgenticProvidersFlowTesting.runBedrockDiscoveryToolRegistration()
        },
        TestFlow(
            ID.bedrock_structured_output_lowering,
            tags: ["aws", "bedrock", "structured-output", "offline"]
        ) {
            try await AgenticProvidersFlowTesting.runBedrockStructuredOutputLowering()
        },
        TestFlow(
            ID.bedrock_live_nested_profile_api,
            tags: ["aws", "bedrock", "model-discovery", "model-routing", "live"]
        ) {
            try await AgenticProvidersFlowTesting.runBedrockLiveNestedProfileAPI()
        },
    ]
}

extension AgenticProvidersFlowSuite {
    enum ID {
        static let apple_prompt_rendering = "apple-prompt-rendering"
        static let apple_tool_bridge = "apple-tool-bridge"
        static let apple_structured_output_lowering = "apple-structured-output-lowering"
        static let apple_model_provider_catalog_realization = "apple-model-provider-catalog-realization"
        static let ollama_missing_configuration_availability = "ollama-missing-configuration-availability"
        static let bedrock_model_provider_catalog_realization = "bedrock-model-provider-catalog-realization"
        static let bedrock_multiple_gateway_provider_realization = "bedrock-multiple-gateway-provider-realization"
        static let bedrock_buffered_stream_completion = "bedrock-buffered-stream-completion"
        static let bedrock_tool_use_stream = "bedrock-tool-use-stream"
        static let bedrock_tool_result_mapping = "bedrock-tool-result-mapping"
        static let bedrock_model_handle_profile_synthesis = "bedrock-model-handle-profile-synthesis"
        static let bedrock_non_streaming_handle_drops_streaming_capability = "bedrock-non-streaming-handle-drops-streaming-capability"
        static let bedrock_generic_snapshot_provider_catalog = "bedrock-generic-snapshot-provider-catalog"
        static let bedrock_discovery_tool_registration = "bedrock-discovery-tool-registration"
        static let bedrock_structured_output_lowering = "bedrock-structured-output-lowering"
        static let bedrock_live_nested_profile_api = "bedrock-live-nested-profile-api"
    }
}
