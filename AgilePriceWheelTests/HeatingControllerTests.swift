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
    @Test func decodeSupervisorAndRecoveryWithoutClaimingLiveControl() throws {
        let data = Data("""
        {"control_enabled":false,"mode":"plan_only","stale":false,"price_requests_heat":true,
         "current":{"agile_price_p":-2,"effective_price_p":-1,"pv_kwh":1,"grid_kwh":1},
         "error":null,"message":"Live heating disabled",
         "heating_control":{"phase":"recovery_required","control_enabled":false,
          "recovery_pending":true,"last_checked_at":"2026-10-24T12:00:00.123456+00:00",
          "observation":null,"error":"Recovery pending","blockers":["Expiry unverified"]}}
        """.utf8)
        let status = try JSONDecoder().decode(ControllerStatus.self, from: data)
        let control = try #require(status.heating_control)
        #expect(!status.control_enabled)
        #expect(control.summary == "Heating recovery needs attention")
        #expect(control.recovery_pending)
        let checked = try #require(control.checkedDate())
        #expect(control.isFresh(at: checked.addingTimeInterval(30)))
        #expect(!control.isFresh(at: checked.addingTimeInterval(46)))
        #expect(!control.isFresh(at: checked.addingTimeInterval(-1)))
    }
    @Test func observationRemainsExplicitlyUnverified() throws {
        let data = Data("""
        {"phase":"disabled","control_enabled":false,"recovery_pending":false,
         "last_checked_at":"2026-10-24T12:00:00+00:00","error":null,"blockers":[],
         "observation":{"disabled":true,"reported_heating_on":false,"room_c":19.5,
          "observed_at":"2026-10-24T12:00:00+00:00","sensor_age_s":0,
          "sensor_candidate_fresh":true,"sensor_contract_verified":false}}
        """.utf8)
        let control = try JSONDecoder().decode(HeatingControlStatus.self, from: data)
        let observation = try #require(control.observation)
        #expect(observation.disabled)
        #expect(!observation.reported_heating_on)
        #expect(!observation.sensor_contract_verified)
        #expect(control.summary == "Automatic heating is disabled")
        #expect(control.checkedDate() != nil)
    }

    @Test func reportedStateRequiresFreshHomelyObservation() throws {
        let checked = "2026-10-25T12:00:00+00:00"
        let now = try #require(ISO8601DateFormatter().date(from: checked))
        func status(heating: Bool, fresh: Bool) -> ControllerStatus {
            let observation = HeatingObservation(disabled: false, reported_heating_on: heating,
                room_c: 19, observed_at: checked, sensor_age_s: fresh ? 0 : 180,
                sensor_candidate_fresh: fresh, sensor_contract_verified: false)
            let control = HeatingControlStatus(phase: "disabled", control_enabled: false,
                recovery_pending: false, last_checked_at: checked, observation: observation,
                error: nil, blockers: [])
            return ControllerStatus(control_enabled: false, mode: "plan_only", stale: false,
                price_requests_heat: false, current: nil, error: nil, message: "", heating_control: control)
        }
        #expect(status(heating: true, fresh: true).reportedHeatingState(at: now) == true)
        #expect(status(heating: false, fresh: true).reportedHeatingState(at: now) == false)
        #expect(status(heating: false, fresh: false).reportedHeatingState(at: now) == nil)
        #expect(status(heating: true, fresh: true).reportedHeatingState(at: now.addingTimeInterval(46)) == nil)
    }

}
