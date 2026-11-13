import Agentic
import AWSConnector

enum BedrockUsageMapper {
    static func map(
        _ usage: Bedrock.Converse.Usage?
    ) -> AgentUsage? {
        guard let usage else {
            return nil
        }

        // Bedrock's inputTokens already excludes cache reads and writes.
        return .init(
            inputTokens: usage.inputTokens,
            outputTokens: usage.outputTokens,
            totalTokens: usage.totalTokens,
            cachedInputReadTokens: usage.cacheReadInputTokens,
            cachedInputWriteTokens: usage.cacheWriteInputTokens
        )
    }
}
