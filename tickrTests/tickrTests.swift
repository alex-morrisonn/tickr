import Testing
@testable import tickr

struct ImpactLevelTests {
    @Test
    func impactLevelsExposeStableOrderingAndLabels() {
        #expect(ImpactLevel.low.rank < ImpactLevel.medium.rank)
        #expect(ImpactLevel.medium.rank < ImpactLevel.high.rank)
        #expect(ImpactLevel.allCases.map(\.label) == ["Low", "Medium", "High"])
    }
}
