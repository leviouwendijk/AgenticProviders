import TestFlows

@main
struct AgenticProvidersFlowTesting {
    static func main() async {
        await TestFlowCLI.run(
            suite: AgenticProvidersFlowSuite.self
        )
    }
}
