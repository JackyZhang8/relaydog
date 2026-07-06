import XCTest
@testable import RelayDogCore

final class ModelMapperTests: XCTestCase {
    func testRewritesTopLevelModelWhenMappingExists() throws {
        let body = #"{"model":"gpt-5.5","messages":[{"role":"user","content":"hi"}]}"#.data(using: .utf8)!

        let result = try ModelMapper.rewriteRequestBody(body, mappings: ["gpt-5.5": "glm5.2"])
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: result.body) as? [String: Any])

        XCTAssertEqual(json["model"] as? String, "glm5.2")
        XCTAssertEqual(result.originalModel, "gpt-5.5")
        XCTAssertEqual(result.mappedModel, "glm5.2")
    }

    func testLeavesBodyUnchangedWhenMappingMisses() throws {
        let body = #"{"model":"glm5.2","stream":true}"#.data(using: .utf8)!

        let result = try ModelMapper.rewriteRequestBody(body, mappings: ["gpt-5.5": "glm5.2"])

        XCTAssertEqual(result.body, body)
        XCTAssertEqual(result.originalModel, "glm5.2")
        XCTAssertNil(result.mappedModel)
    }
}
