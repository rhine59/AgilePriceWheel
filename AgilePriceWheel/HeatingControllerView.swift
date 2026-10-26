import SwiftUI
import Security

struct ControllerPolicy: Codable {
    static let priceChoices = -20...20
    var on_price_p: Double
    var off_price_p: Double
    var target_c: Double
    var limit_c: Double
    var product: String
    var tariff: String
    var latitude: Double
    var longitude: Double
    var array_kwp: Double
    var loss_percent: Double
    var inverter_kw: Double
    var load_kw: Double
}
struct PolicyDocument: Codable {
    var revision: Int
    var policy: ControllerPolicy
}
struct AutomationState: Decodable {
    let revision: Int
    let enabled: Bool
    let can_enable: Bool
    let shutdown_pending: Bool
    let phase: String
    let error: String?
}
struct ControllerStatus: Decodable {
    let control_enabled: Bool
    let mode: String
    let stale: Bool
    let price_requests_heat: Bool
    let current: ControllerSlot?
    let error: String?
    let message: String
    let heating_control: HeatingControlStatus?

    var supportedControlMode: Bool {
        (mode == "plan_only" && !control_enabled) || (mode == "automatic" && control_enabled)
    }

    func reportedHeatingState(at now: Date) -> Bool? {
        guard let control = heating_control, control.isFresh(at: now), control.error == nil,
              let observation = control.observation else { return nil }
        return observation.reported_heating_on
    }
}
struct HeatingControlStatus: Decodable {
    let phase: String
    let control_enabled: Bool
    let recovery_pending: Bool
    let last_checked_at: String?
    let observation: HeatingObservation?
    let error: String?
    let blockers: [String]

    var summary: String {
        if recovery_pending { return "Heating recovery needs attention" }
        switch phase {
        case "disabled": return "Automatic heating is disabled"
        case "blocked": return "Automatic heating is not ready"
        case "boost_active": return "Price policy boost is active"
        case "heating_off": return "Price policy heating is off"
        case "automation_off": return "Automation is off"
        case "waiting_for_boundary": return "Waiting for the next half-hour"
        case "manual_change_hold": return "Paused after a manual change"
        case "unavailable": return "Heating checks are unavailable"
        case "recovery_required": return "Heating recovery needs attention"
        default: return "Check heating status on the controller"
        }
    }
    func checkedDate() -> Date? {
        guard let last_checked_at else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: last_checked_at) ?? ISO8601DateFormatter().date(from: last_checked_at)
    }
    func isFresh(at now: Date = Date()) -> Bool {
        guard let date = checkedDate() else { return false }
        return (0...45).contains(now.timeIntervalSince(date))
    }
}
struct HeatingObservation: Decodable {
    let disabled: Bool
    let reported_heating_on: Bool
    let room_c: Double
    let observed_at: String
    let sensor_age_s: Double
    let sensor_candidate_fresh: Bool
    let sensor_contract_verified: Bool
}
struct ControllerSlot: Decodable {
    let agile_price_p: Double
    let effective_price_p: Double
    let pv_kwh: Double
    let grid_kwh: Double
}

private enum ControllerKeychain {
    static func query(_ host: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "AgilePriceWheel.HeatingController",
         kSecAttrAccount as String: host]
    }
    static func read(_ host: String) -> String {
        var query = query(host)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
    static func save(_ token: String, host: String) throws {
        let base = query(host)
        let values: [String: Any] = [kSecValueData as String: Data(token.utf8),
                                   kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let update = SecItemUpdate(base as CFDictionary, values as CFDictionary)
        if update == errSecSuccess { return }
        guard update == errSecItemNotFound else { throw ControllerFailure.message("Could not store the controller key securely.") }
        var item = base
        values.forEach { item[$0.key] = $0.value }
        guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else {
            throw ControllerFailure.message("Could not store the controller key securely.")
        }
    }
}

enum ControllerFailure: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}
private final class NoControllerRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil) // Never forward the controller key to another host.
    }
}

struct ControllerAPI {
    let base: URL
    let token: String
    static func endpoint(_ text: String) throws -> URL {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "https", url.host != nil, url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil, url.path.isEmpty || url.path == "/" else {
            throw ControllerFailure.message("Enter the controller's HTTPS address, without a path or password.")
        }
        return url
    }
    func request<T: Decodable>(_ path: String, body: PolicyDocument? = nil, automationEnabled: Bool? = nil, queryItems: [URLQueryItem] = []) async throws -> T {
        let endpoint = base.appendingPathComponent("v1").appendingPathComponent(path)
        guard var parts = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else { throw ControllerFailure.message("Invalid controller address.") }
        if !queryItems.isEmpty { parts.queryItems = queryItems }
        guard let url = parts.url else { throw ControllerFailure.message("Invalid controller address.") }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        } else if let automationEnabled {
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(["enabled": automationEnabled])
        }
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        let session = URLSession(configuration: config, delegate: NoControllerRedirects(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ControllerFailure.message("No controller response.") }
        guard http.statusCode == 200 else {
            if http.statusCode == 401 { throw ControllerFailure.message("The controller key was not accepted.") }
            if http.statusCode == 409 { throw ControllerFailure.message(path == "automation" ? "Automatic heating has not been activated on this controller." : "The policy changed elsewhere. Reload before saving.") }
            if path == "history" { throw ControllerFailure.message("Heating history is temporarily unavailable. Try reloading.") }
            if http.statusCode == 400 { throw ControllerFailure.message("The controller rejected the policy. Check signed prices and PV settings.") }
            throw ControllerFailure.message("The controller is unavailable (\(http.statusCode)).")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

struct HeatingControllerView: View {
    @ObservedObject var agileModel: AgileViewModel
    @ObservedObject var solarModel: SolarForecastModel
    @ObservedObject var settings: AppSettingsStore
    @AppStorage("heating.controller.address") private var address = ""
    @AppStorage("heating.controller.connectionRevision") private var connectionRevision = 0
    @State private var token = ""
    @State private var document: PolicyDocument?
    @State private var status: ControllerStatus?
    @State private var automation: AutomationState?
    @State private var confirmAutomationOn = false
    @State private var showHistory = false
    @State private var connectedAddress: String?
    @State private var onPrice = "0"
    @State private var offPrice = "0"
    @State private var busy = false
    @State private var message: String?
    @State private var messageIsError = false
    @State private var confirmSave = false
    @State private var checkedAt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            TimelineView(.periodic(from: .now, by: 5)) { context in
                let recent = checkedAt.map { (0...45).contains(context.date.timeIntervalSince($0)) } ?? false
                let currentStatus = recent ? status : nil
                VStack(alignment: .leading, spacing: 8) {
                    heatingStateLine("Heating policy", isOn: currentStatus.map {
                        !$0.stale && $0.current != nil && $0.price_requests_heat
                    }, identifier: "heating-policy-decision")
                    heatingStateLine("Heating state", isOn: currentStatus?.reportedHeatingState(at: context.date),
                                     identifier: "heating-reported-state",
                                     lastReported: currentStatus?.heating_control?.observation?.sensor_candidate_fresh == false)
                    Text("Policy is price permission. State is Homely’s report. Automatic control is \(status?.control_enabled == true ? "enabled" : "disabled").")
                        .font(.caption).foregroundStyle(.blue)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Automation", isOn: Binding(
                        get: { automation?.enabled ?? false },
                        set: { enabled in
                            if enabled { confirmAutomationOn = true }
                            else { Task { await setAutomation(false) } }
                        }
                    ))
                    .accessibilityIdentifier("heating-automation-switch")
                    .disabled(busy || automation == nil || (automation?.enabled == false && automation?.can_enable == false))
                    if automation == nil {
                        Text("Connect to the controller to check automation state.").foregroundStyle(.blue)
                    } else if automation?.shutdown_pending == true {
                        Text("Automation is OFF. Heating shutdown is pending; check Heating state.").foregroundStyle(.red)
                    } else {
                        Text("OFF stops policy heating and keeps automation off after restarts. You can then use Homely manually.").foregroundStyle(.blue)
                    }
                    if let error = automation?.error { Text(error).foregroundStyle(.red) }
                    if automation?.shutdown_pending == true || automation?.error != nil {
                        Button("Retry switching off") { Task { await setAutomation(false) } }.disabled(busy)
                    }
                }.font(.subheadline)
            }
            Text("Agile + forecast PV determine the effective heating price. The controller keeps the policy running when this app is closed.")
                .foregroundStyle(.blue)
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Label(status?.control_enabled == true ? "Automatic control enabled" : "Automatic control disabled", systemImage: "lock.shield")
                        .font(.headline).foregroundStyle(.orange)
                    Text(status?.control_enabled == true ? "The controller applies this policy at :00 and :30, using Homely’s existing temperature targets. Saving a policy also releases a manual-change pause." : "Review effective prices and save your heating policy here. Saving a policy does not activate automatic heating.")
                        .font(.subheadline).foregroundStyle(.blue)
                    if let checkedAt {
                        Text("Last checked \(checkedAt.formatted(date: .omitted, time: .standard))").font(.caption).foregroundStyle(.secondary)
                    }
                    if let status {
                        if let current = status.current {
                            LabeledContent("Effective price", value: String(format: "%.2f p/kWh", current.effective_price_p))
                            LabeledContent("Agile grid price", value: String(format: "%.2f p/kWh", current.agile_price_p))
                            LabeledContent("Forecast PV", value: String(format: "%.3f kWh", current.pv_kwh))
                        }
                        if let error = status.error { Text(error).foregroundStyle(.red) }
                        if let control = status.heating_control {
                            Divider()
                            Text(control.summary).font(.headline)
                                .foregroundStyle(control.recovery_pending || control.error != nil ? Color.red : Color.blue)
                                .accessibilityIdentifier("heating-supervisor-summary")
                            if let checked = control.checkedDate() {
                                Text("Heating checks: \(checked.formatted(date: .omitted, time: .standard))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            if !control.isFresh() {
                                Text("Heating checks have not reported recently. This is not a live heating reading.")
                                    .font(.caption).foregroundStyle(.red)
                            }
                            if let error = control.error { Text(error).foregroundStyle(.red) }
                            if !control.blockers.isEmpty {
                                Text(control.blockers.joined(separator: " "))
                                    .font(.caption).foregroundStyle(.blue)
                            }
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            Button("Test connection / reload controller policy") { Task { await load() } }
                .buttonStyle(.borderedProminent).disabled(busy)
            Button("Weekly heating log", systemImage: "clock.arrow.circlepath") { showHistory = true }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("heating-weekly-log")
                .disabled(busy || connectedAddress != address || token.count < 32)
            if let document {
                GroupBox("Heating price policy") {
                    VStack(spacing: 12) {
                        policyPicker("Heating on", text: $onPrice, range: ControllerPolicy.priceChoices, unit: "p/kWh")
                        policyPicker("Heating off", text: $offPrice, range: ControllerPolicy.priceChoices, unit: "p/kWh")
                        Text("On at or below; off above. Hold the decision between prices. Negative prices mean payment for grid import. Homely keeps its existing temperature targets.")
                            .font(.caption).foregroundStyle(.blue)
                        LabeledContent("Policy revision", value: String(document.revision))
                        Text("Controller tariff: \(document.policy.tariff.isEmpty ? "Not configured" : document.policy.tariff)")
                            .font(.caption).textSelection(.enabled)
                        LabeledContent("Array capacity", value: String(format: "%.2f kWp", document.policy.array_kwp))
                        LabeledContent("Heating electrical load", value: String(format: "%.2f kW", document.policy.load_kw))
                        LabeledContent("System losses", value: String(format: "%.1f%%", document.policy.loss_percent))
                        LabeledContent("Inverter limit", value: document.policy.inverter_kw > 0 ? String(format: "%.2f kW", document.policy.inverter_kw) : "None")
                        Button("Use this app's tariff, solar site and PV settings") { copyAppSettings() }
                            .disabled(busy)
                        Text("Copies the configured optimiser load, capacity, losses and inverter limit into this draft. Saving applies it to the controller.")
                            .font(.caption).foregroundStyle(.blue)
                        Button("Save policy to controller") { confirmSave = true }
                            .buttonStyle(.borderedProminent).disabled(busy || connectedAddress != address)
                    }
                }
            }
            if busy { ProgressView("Contacting controller…") }
            if let message {
                Label(message, systemImage: messageIsError ? "exclamationmark.triangle" : "info.circle")
                    .foregroundStyle(messageIsError ? Color.red : Color.blue)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("controller-message")
            }
            Text("Effective price = expected grid cost ÷ heating-load energy, after forecast PV. Forecasts do not guarantee free electricity. The configured load should represent the heat pump's electrical demand.")
                .font(.caption).foregroundStyle(.blue)
        }
        .task(id: connectedAddress) {
            guard let connectedAddress else { return }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(30))
                    guard address == connectedAddress else { return }
                    let currentToken = token
                    let current: ControllerStatus = try await api().request("status")
                    guard current.supportedControlMode else {
                        status = nil; message = "Controller returned an unsupported control mode."; messageIsError = true; return
                    }
                    let switchState: AutomationState = try await api().request("automation")
                    guard address == connectedAddress, token == currentToken else { return }
                    status = current; automation = switchState; checkedAt = Date()
                } catch {
                    if Task.isCancelled { return }
                    status = nil; message = "Controller status could not be refreshed. Last display is not a live heating state."; messageIsError = true
                }
            }
        }
        .task(id: connectionRevision) {
            token = ControllerKeychain.read(address)
            document = nil; status = nil; automation = nil; connectedAddress = nil
            if !address.isEmpty, token.count >= 32 { await load() }
        }
        .onChange(of: address) { _, value in
            document = nil; status = nil; automation = nil; connectedAddress = nil
            token = ControllerKeychain.read(value); message = nil
        }
        .onChange(of: token) { _, _ in
            document = nil; status = nil; automation = nil; connectedAddress = nil; checkedAt = nil
        }
        .sheet(isPresented: $showHistory) {
            NavigationStack { HeatingHistoryView(address: address, token: token) }
                .preferredColorScheme(.dark)
        }
        .confirmationDialog("Enable automated heating?", isPresented: $confirmAutomationOn, titleVisibility: .visible) {
            Button("Enable automation") { Task { await setAutomation(true) } }
        } message: {
            Text("The controller will use the saved price policy from the next half-hour, with Homely’s existing temperature targets. Switching OFF will stop heating.")
        }
        .confirmationDialog("Save this heating policy to the controller?", isPresented: $confirmSave, titleVisibility: .visible) {
            Button("Save policy") { Task { await save() } }
        } message: {
            Text("On at or below \(onPrice)p; off above \(offPrice)p. Homely keeps its existing temperature targets. Saving does not change automatic activation. If already active, it stops the current boost, releases a manual pause and applies the policy from the next half-hour.")
        }
    }
    private func heatingStateLine(_ title: String, isOn: Bool?, identifier: String, lastReported: Bool = false) -> some View {
        let state = isOn.map { $0 ? "ON" : "OFF" } ?? "unavailable"
        let value = state + (isOn != nil && lastReported ? " (last reported)" : "")
        let colour: Color = isOn == true ? .red : (isOn == false ? .green : .secondary)
        return Text("\(title): \(value)")
            .font(.title3.bold()).foregroundStyle(colour)
            .accessibilityIdentifier(identifier)
    }
    private func pickerValue(_ text: String, range: ClosedRange<Int>) -> String {
        guard let number = Double(text), number.isFinite,
              number >= Double(range.lowerBound), number <= Double(range.upperBound),
              number.rounded() == number else { return text }
        return String(Int(number))
    }
    private func policyPicker(_ title: String, text: Binding<String>, range: ClosedRange<Int>, unit: String) -> some View {
        let selected = pickerValue(text.wrappedValue, range: range)
        let choices = range.map { String($0) }
        return LabeledContent(title + " -") {
            Picker(title, selection: Binding(
                get: { pickerValue(text.wrappedValue, range: range) },
                set: { text.wrappedValue = $0 }
            )) {
                if !choices.contains(selected) {
                    Text("Current: \(text.wrappedValue) \(unit)").tag(selected)
                }
                ForEach(choices, id: \.self) { value in
                    Text("\(value) \(unit)").tag(value)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .accessibilityIdentifier("heating-policy-" + title)
        }
        .disabled(busy)
    }

    private func api() throws -> ControllerAPI {
        guard !address.isEmpty, token.count >= 32 else { throw ControllerFailure.message("Set the controller address and key in App Settings first.") }
        return ControllerAPI(base: try ControllerAPI.endpoint(address), token: token)
    }
    @MainActor private func load() async {
        busy = true; message = nil; messageIsError = false; document = nil; status = nil; automation = nil
        defer { busy = false }
        let original = address
        let originalToken = token
        do {
            let api = try api()
            let loaded: PolicyDocument = try await api.request("policy")
            let current: ControllerStatus = try await api.request("status")
            let switchState: AutomationState = try await api.request("automation")
            guard original == address, originalToken == token else { return }
            guard current.supportedControlMode else {
                throw ControllerFailure.message("Controller returned an unsupported control mode.")
            }
            try ControllerKeychain.save(token, host: address)
            document = loaded; status = current; automation = switchState; checkedAt = Date(); connectedAddress = address
            onPrice = String(loaded.policy.on_price_p); offPrice = String(loaded.policy.off_price_p)
        } catch { message = error.localizedDescription; messageIsError = true }
    }
    @MainActor private func setAutomation(_ enabled: Bool) async {
        busy = true; message = nil; messageIsError = false
        defer { busy = false }
        let original = address
        let originalToken = token
        do {
            let api = try api()
            let result: AutomationState = try await api.request("automation", automationEnabled: enabled)
            guard address == original, token == originalToken else { return }
            let refreshed: ControllerStatus = try await api.request("status")
            guard address == original, token == originalToken else { return }
            automation = result; status = refreshed; checkedAt = Date()
            message = enabled ? "Automation enabled. Waiting for the next half-hour policy decision." : "Automation switched OFF. Heating state will refresh as shutdown is confirmed."
        } catch {
            guard address == original, token == originalToken else { return }
            // A lost PUT response is reconciled with GET; never blindly replay it.
            if let api = try? api() { automation = try? await api.request("automation") }
            status = nil
            message = "Could not confirm the automation change. Reload to check its saved state. " + error.localizedDescription
            messageIsError = true
        }
    }
    private func numeric(_ text: String) throws -> Double {
        guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")), value.isFinite else {
            throw ControllerFailure.message("Enter finite numbers for prices.")
        }
        return value
    }
    @MainActor private func save() async {
        busy = true; message = nil; messageIsError = false
        defer { busy = false }
        let original = address
        let originalToken = token
        do {
            guard var draft = document, connectedAddress == address else { return }
            draft.policy.on_price_p = try numeric(onPrice); draft.policy.off_price_p = try numeric(offPrice)
            guard draft.policy.off_price_p >= draft.policy.on_price_p else {
                throw ControllerFailure.message("Off price must be at least on price.")
            }
            let api = try api()
            let result: PolicyDocument = try await api.request("policy", body: draft)
            guard original == address, originalToken == token else { return }
            document = result; status = nil
            message = "Policy saved to controller. Automatic activation is unchanged. Reload shortly for refreshed prices."
        } catch { message = error.localizedDescription; messageIsError = true }
    }
    private func copyAppSettings() {
        messageIsError = false
        guard var draft = document, let tariff = agileModel.selectedTariff, let site = solarModel.site,
              settings.hasPVPanelsInstalled, let capacity = settings.effectivePeakPowerKWp,
              let load = settings.effectiveOptimiserLoadKW else {
            message = "Choose a tariff, solar site, PV capacity and heating-load power in App Settings first."; messageIsError = true; return
        }
        draft.policy.tariff = tariff.tariffCode
        draft.policy.product = tariff.productCode
        draft.policy.latitude = site.latitude; draft.policy.longitude = site.longitude
        draft.policy.array_kwp = capacity; draft.policy.loss_percent = 100 * (1 - settings.generationLossFactor)
        draft.policy.inverter_kw = settings.effectiveInverterMaxKW ?? 0
        draft.policy.load_kw = load
        document = draft
        message = "App tariff and PV settings copied into the draft. Save to apply to the controller."
    }
}


struct HeatingConnectionSettingsView: View {
    @AppStorage("heating.controller.address") private var savedAddress = ""
    @AppStorage("heating.controller.connectionRevision") private var connectionRevision = 0
    @State private var draftAddress = ""
    @State private var draftKey = ""
    @State private var message: String?
    @State private var isError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Controller HTTPS address", text: $draftAddress)
                .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                .accessibilityIdentifier("heating-controller-address")
            SecureField("Controller key", text: $draftKey)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .accessibilityIdentifier("heating-controller-key")
            Button("Save connection") { saveConnection() }
                .buttonStyle(.borderedProminent)
            if let message {
                Label(message, systemImage: isError ? "exclamationmark.triangle" : "info.circle")
                    .font(.caption).foregroundStyle(isError ? Color.red : Color.blue)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("The key is stored in Keychain. Test the connection on Agile heating; saving here does not change its policy.")
                .font(.caption).foregroundStyle(.blue)
        }
        .textFieldStyle(.roundedBorder)
        .onAppear {
            draftAddress = savedAddress
            draftKey = ControllerKeychain.read(savedAddress)
        }
    }

    private func saveConnection() {
        do {
            let endpoint = try ControllerAPI.endpoint(draftAddress)
            let origin = endpoint.absoluteString.hasSuffix("/") ? String(endpoint.absoluteString.dropLast()) : endpoint.absoluteString
            let key = draftKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard key.count >= 32, !key.contains("\n"), !key.contains("\r") else {
                throw ControllerFailure.message("Enter the controller key (at least 32 characters, on one line).")
            }
            try ControllerKeychain.save(key, host: origin)
            savedAddress = origin; draftAddress = origin; draftKey = key
            connectionRevision += 1
            isError = false
            message = "Connection saved. Use Test connection / reload controller policy on Agile heating."
        } catch {
            isError = true; message = error.localizedDescription
        }
    }
}


enum HeatingHistoryState: String, Decodable, Equatable { case on, off }
struct HeatingHistoryEvent: Decodable, Identifiable {
    let id: String
    let at: String
    let state: HeatingHistoryState
    let reason: String
    let price_p: Double?
    let on_price_p: Double?
    let off_price_p: Double?
    let source: String
    var isOn: Bool { state == .on }
    var isTest: Bool { source == "supervised_test" }
    var reasonLabel: String {
        switch reason {
        case "price_policy_start": return "Price policy"
        case "price_above_off": return "Price above off point"
        case "policy_changed": return "Policy changed"
        case "automation_off": return "Automation switched off"
        case "recovery": return "Controller recovery"
        case "data_unavailable": return "Price data unavailable"
        case "setup_timeout": return "Heating setup timed out"
        case "missed_boundary": return "Missed slot boundary"
        case "supervised_start", "supervised_stop": return "Reviewed supervised test"
        default: return "Controller action"
        }
    }
}
struct HeatingHistoryDocument: Decodable {
    let week_start: String
    let week_end: String
    let current_week: String
    let oldest_week: String
    let timezone: String
    let recording_started_at: String?
    let retention_days: Int
    let truncated: Bool
    let events: [HeatingHistoryEvent]
    let pending_events: Int
    let warning: String?
    var canGoBack: Bool { week_start > oldest_week }
    var canGoForward: Bool { week_start < current_week }
}
enum HeatingHistoryDates {
    static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Europe/London")!
        value.firstWeekday = 2
        value.minimumDaysInFirstWeek = 4
        return value
    }
    static func date(_ day: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar; formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone; formatter.dateFormat = "yyyy-MM-dd"; formatter.isLenient = false
        return formatter.date(from: day)
    }
    static func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar; formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone; formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    static func shifted(_ week: String, by weeks: Int) -> String? {
        guard let start = date(week), let moved = calendar.date(byAdding: .day, value: 7 * weeks, to: start) else { return nil }
        return day(moved)
    }
    static func eventDate(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }
    static func eventText(_ text: String) -> String {
        guard let date = eventDate(text) else { return "Time unavailable" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB"); formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone; formatter.dateFormat = "EEE d MMM, HH:mm:ss z"
        return formatter.string(from: date)
    }
    static func range(_ start: String, _ end: String) -> String {
        guard let a = date(start), let b = date(end), let last = calendar.date(byAdding: .day, value: -1, to: b) else { return start }
        let formatter = DateIntervalFormatter()
        formatter.locale = Locale(identifier: "en_GB"); formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone; formatter.dateStyle = .medium; formatter.timeStyle = .none
        return formatter.string(from: a, to: last)
    }
}
struct HeatingHistoryView: View {
    let address: String
    let token: String
    @Environment(\.dismiss) private var dismiss
    @State private var document: HeatingHistoryDocument?
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        List {
            Section {
                HStack {
                    Button { Task { await move(-1) } } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("Previous week").disabled(busy || document?.canGoBack != true)
                    Spacer()
                    Text(document.map { HeatingHistoryDates.range($0.week_start, $0.week_end) } ?? "Current week")
                        .font(.headline).multilineTextAlignment(.center)
                    Spacer()
                    Button { Task { await move(1) } } label: { Image(systemName: "chevron.right") }
                        .accessibilityLabel("Next week").disabled(busy || document?.canGoForward != true)
                }.buttonStyle(.borderless)
                Text("Confirmed controller actions · UK time. Manual Homely changes are not included.")
                    .font(.caption).foregroundStyle(.blue)
                if busy { ProgressView("Loading heating log…") }
                if let error { Text(error).foregroundStyle(.red) }
                if let warning = document?.warning { Text(warning).font(.caption).foregroundStyle(.red) }
                if (document?.pending_events ?? 0) > 0 {
                    Text("Some confirmed changes are waiting to be saved.").font(.caption).foregroundStyle(.red)
                }
            }
            if let document {
                Section("Heating changes") {
                    if document.events.isEmpty {
                        Text("No recorded heating changes this week.").foregroundStyle(.blue)
                    }
                    ForEach(document.events) { event in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(event.isOn ? "Heating ON" : "Heating OFF")
                                    .font(.headline).foregroundStyle(event.isOn ? Color.red : Color.green)
                                Spacer()
                                if event.isTest { Text("Test").font(.caption).foregroundStyle(.blue) }
                            }
                            Text(HeatingHistoryDates.eventText(event.at)).font(.subheadline)
                            Text(event.reasonLabel).font(.caption).foregroundStyle(.secondary)
                            if let price = event.price_p {
                                Text(String(format: "Effective price: %.2f p/kWh", price)).font(.caption)
                            }
                            if let on = event.on_price_p, let off = event.off_price_p {
                                Text(String(format: "On ≤ %g p · Off > %g p", on, off)).font(.caption).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 4)
                    }
                }
                Section {
                    if let began = document.recording_started_at {
                        Text("Automatic logging began \(HeatingHistoryDates.eventText(began)). Test entries, if present, are labelled.")
                    }
                    Text("Times show controller confirmations, not electricity-use measurements. History is retained for about a year.")
                    if document.truncated { Text("This week has too many entries to display completely.").foregroundStyle(.red) }
                }.font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Weekly heating log")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            ToolbarItem(placement: .primaryAction) {
                Button { Task { await load(document?.week_start) } } label: { Image(systemName: "arrow.clockwise") }
                    .accessibilityLabel("Reload heating log").disabled(busy)
            }
        }
        .task { await load(nil) }
        .refreshable { await load(document?.week_start) }
    }
    @MainActor private func move(_ direction: Int) async {
        guard let current = document?.week_start, let week = HeatingHistoryDates.shifted(current, by: direction) else { return }
        await load(week)
    }
    @MainActor private func load(_ week: String?) async {
        guard !busy else { return }
        busy = true; error = nil
        defer { busy = false }
        do {
            let api = ControllerAPI(base: try ControllerAPI.endpoint(address), token: token)
            let query = week.map { [URLQueryItem(name: "week", value: $0)] } ?? []
            let result: HeatingHistoryDocument = try await api.request("history", queryItems: query)
            guard !Task.isCancelled else { return }
            document = result
        } catch {
            if Task.isCancelled { return }
            self.error = "Could not refresh the heating log. " + error.localizedDescription
        }
    }
}
