import Foundation
import Testing
@testable import AgilePriceWheel

struct HeatingControllerTests {
    @Test func requiresPrivateHTTPSOrigin() throws {
        #expect(try ControllerAPI.endpoint("https://heating.example.com:8443").host == "heating.example.com")
        for value in ["http://nas:8080", "https://user:password@nas", "https://nas/api", "https://nas?key=secret"] {
            #expect(throws: (any Error).self) { try ControllerAPI.endpoint(value) }
        }
    }
    @Test func policyWireFormatPreservesSolarSettings() throws {
        let policy = ControllerPolicy(on_price_p: 0, off_price_p: 5, target_c: 21, limit_c: 22,
                                      product: "AGILE-EXAMPLE", tariff: "E-1R-AGILE-EXAMPLE-G",
                                      latitude: 54, longitude: -2, array_kwp: 5, loss_percent: 15,
                                      inverter_kw: 4, load_kw: 3)
        let source = PolicyDocument(revision: 4, policy: policy)
        let data = try JSONEncoder().encode(source)
        let restored = try JSONDecoder().decode(PolicyDocument.self, from: data)
        #expect(restored.revision == 4)
        #expect(restored.policy.off_price_p == 5)
        #expect(restored.policy.array_kwp == 5)
        #expect(restored.policy.loss_percent == 15)
        #expect(restored.policy.load_kw == 3)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == Set(["revision", "policy"]))
    }
    @Test func decodePlanOnlyStatus() throws {
        let data = Data("""
        {"control_enabled":false,"mode":"plan_only","stale":true,"price_requests_heat":false,
        "current":null,"error":"No prices","message":"Live heating disabled"}
        """.utf8)
        let value = try JSONDecoder().decode(ControllerStatus.self, from: data)
        #expect(!value.control_enabled)
        #expect(value.stale)
        #expect(value.current == nil)
    }
}
