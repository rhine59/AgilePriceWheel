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

    @Test func reportedStateRequiresRecentSuccessfulHomelyPoll() throws {
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
        #expect(status(heating: false, fresh: false).reportedHeatingState(at: now) == false)
        #expect(status(heating: true, fresh: true).reportedHeatingState(at: now.addingTimeInterval(46)) == nil)
    }

    @Test func negativePolicyPricesAndZeroAreSelectableAndPreserved() throws {
        #expect(ControllerPolicy.priceChoices.contains(-5))
        #expect(ControllerPolicy.priceChoices.contains(0))
        #expect(ControllerPolicy.priceChoices.contains(20))
        let policy = ControllerPolicy(on_price_p: -5, off_price_p: -1, target_c: 21, limit_c: 22,
            product: "", tariff: "", latitude: 54, longitude: -2, array_kwp: 5,
            loss_percent: 15, inverter_kw: 4, load_kw: 3)
        let restored = try JSONDecoder().decode(ControllerPolicy.self, from: JSONEncoder().encode(policy))
        #expect(restored.on_price_p == -5)
        #expect(restored.off_price_p == -1)
    }
    @Test func acceptsConsistentAutomaticAndPlanOnlyModes() throws {
        func decoded(_ enabled: Bool, _ mode: String) throws -> ControllerStatus {
            let data = Data("{\"control_enabled\":\(enabled),\"mode\":\"\(mode)\",\"stale\":false,\"price_requests_heat\":false,\"current\":null,\"error\":null,\"message\":\"\"}".utf8)
            return try JSONDecoder().decode(ControllerStatus.self, from: data)
        }
        #expect(try decoded(true, "automatic").supportedControlMode)
        #expect(try decoded(false, "plan_only").supportedControlMode)
        #expect(try !decoded(false, "automatic").supportedControlMode)
        #expect(try !decoded(true, "plan_only").supportedControlMode)
    }

    @Test func automationOffPendingIsDistinctFromConfirmedHeatingOff() throws {
        let data = Data("{\"revision\":2,\"enabled\":false,\"can_enable\":false,\"shutdown_pending\":true,\"phase\":\"recovery_required\",\"error\":null}".utf8)
        let value = try JSONDecoder().decode(AutomationState.self, from: data)
        #expect(!value.enabled)
        #expect(value.shutdown_pending)
        #expect(!value.can_enable)
    }

    @Test func historyRetainsNegativePricesAndTestLabels() throws {
        let data = Data("""
        {"week_start":"2026-10-19","week_end":"2026-10-26","current_week":"2026-10-19","oldest_week":"2026-10-19","timezone":"Europe/London","recording_started_at":"2026-10-25T18:00:00.000Z","retention_days":366,"truncated":false,"pending_events":0,"warning":null,"events":[{"id":"one","at":"2026-10-25T18:00:00.000Z","state":"on","reason":"supervised_start","price_p":-5,"on_price_p":-5,"off_price_p":-1,"source":"supervised_test"}]}
        """.utf8)
        let value = try JSONDecoder().decode(HeatingHistoryDocument.self, from: data)
        #expect(value.events.count == 1)
        #expect(value.events[0].isOn)
        #expect(value.events[0].isTest)
        #expect(value.events[0].price_p == -5)
        #expect(!value.canGoBack)
        #expect(!value.canGoForward)
    }
    @Test func historyWeeksUseLondonDSTAndExplicitRepeatedHourLabels() throws {
        let start = try #require(HeatingHistoryDates.date("2026-10-19"))
        let end = try #require(HeatingHistoryDates.date("2026-10-26"))
        #expect(end.timeIntervalSince(start) == 169 * 3600)
        #expect(HeatingHistoryDates.shifted("2026-10-19", by: 1) == "2026-10-26")
        let first = HeatingHistoryDates.eventText("2026-10-25T00:30:00.000Z")
        let second = HeatingHistoryDates.eventText("2026-10-25T01:30:00.000Z")
        #expect(first.contains("BST"))
        #expect(second.contains("GMT"))
        #expect(first != second)
    }

    @Test func unknownHistoryStateIsNotDisplayedAsOff() {
        let data = Data("{\"id\":\"bad\",\"at\":\"2026-10-25T18:00:00Z\",\"state\":\"unknown\",\"reason\":\"unknown\",\"source\":\"automation\"}".utf8)
        #expect(throws: (any Error).self) { try JSONDecoder().decode(HeatingHistoryEvent.self, from: data) }
    }

    @Test func sessionEstimatesShowPaymentAndMissingCostHonestly() throws {
        let data = Data("""
        {"id":"session","on_at":"2026-10-25T22:00:00Z","off_at":"2026-10-25T22:30:00Z","duration_seconds":1800,"on_price_p":-5,"off_price_p":2,"off_reason":"price_above_off","estimated_cost_gbp":-0.075,"estimated_energy_kwh":1.5,"cost_status":"estimated","intervals":[{"start":"2026-10-25T22:00:00Z","end":"2026-10-25T22:30:00Z","agile_price_p":-5,"effective_price_p":-5,"load_kw":3}]}
        """.utf8)
        let session = try JSONDecoder().decode(HeatingSession.self, from: data)
        #expect(session.costLabel == "Estimated payment: £0.0750")
        #expect(session.durationLabel == "Duration: 0h 30m 0s")
        #expect(session.intervals[0].agile_price_p == -5)
        let missing = HeatingSession(id: "old", on_at: "2026-10-25T22:00:00Z", off_at: nil,
            duration_seconds: nil, on_price_p: 0, off_price_p: nil, off_reason: nil,
            estimated_cost_gbp: nil, estimated_energy_kwh: nil, cost_status: "end_unconfirmed", intervals: [])
        #expect(missing.costLabel.contains("end unconfirmed"))
    }

    @Test func staleOrMissingPriceIsUnavailableRatherThanOff() throws {
        func status(stale: Bool, current: String) throws -> ControllerStatus {
            try JSONDecoder().decode(ControllerStatus.self, from: Data("{\"control_enabled\":false,\"mode\":\"plan_only\",\"stale\":\(stale),\"price_requests_heat\":false,\"current\":\(current),\"error\":null,\"message\":\"\"}".utf8))
        }
        #expect(try status(stale: true, current: "null").pricePolicyState == nil)
        let current = "{\"agile_price_p\":5,\"effective_price_p\":5,\"pv_kwh\":0,\"grid_kwh\":1}"
        #expect(try status(stale: false, current: current).pricePolicyState == false)
        #expect(try status(stale: true, current: current).pricePolicyState == nil)
    }

}
