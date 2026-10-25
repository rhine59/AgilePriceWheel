import SwiftUI
import Security

struct ControllerPolicy: Codable {
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
struct ControllerStatus: Decodable {
    let control_enabled: Bool
    let mode: String
    let stale: Bool
    let price_requests_heat: Bool
    let current: ControllerSlot?
    let error: String?
    let message: String
    let heating_control: HeatingControlStatus?

    func reportedHeatingState(at now: Date) -> Bool? {
        guard let control = heating_control, control.isFresh(at: now),
              let observation = control.observation, observation.sensor_candidate_fresh else { return nil }
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
        case "blocked": return "Automatic heating needs further verification"
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
    func request<T: Decodable>(_ path: String, body: PolicyDocument? = nil) async throws -> T {
        var request = URLRequest(url: base.appendingPathComponent("v1").appendingPathComponent(path))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
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
            if http.statusCode == 409 { throw ControllerFailure.message("The policy changed elsewhere. Reload before saving.") }
            if http.statusCode == 400 { throw ControllerFailure.message("The controller rejected the policy. Check prices, temperatures and PV settings.") }
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
    @State private var token = ""
    @State private var document: PolicyDocument?
    @State private var status: ControllerStatus?
    @State private var connectedAddress: String?
    @State private var onPrice = "0"
    @State private var offPrice = "0"
    @State private var target = "21"
    @State private var limit = "22"
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
                                     identifier: "heating-reported-state")
                    Text("Policy is price permission. State is Homely’s report. Automatic control is disabled.")
                        .font(.caption).foregroundStyle(.blue)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("Agile + forecast PV determine the effective heating price. The controller keeps the policy running when this app is closed.")
                .foregroundStyle(.blue)
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Automatic control disabled", systemImage: "lock.shield")
                        .font(.headline).foregroundStyle(.orange)
                    Text("Review effective prices and save your heating policy here. Automatic heating remains blocked until its safety timeout, restoration and temperature checks are verified.")
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
                            if let observation = control.observation {
                                LabeledContent("Reported room temperature", value: String(format: "%.1f°C", observation.room_c))
                                LabeledContent("Space heating disabled", value: observation.disabled ? "Yes" : "No")
                                LabeledContent("Homely reports heating", value: observation.reported_heating_on ? "On" : "Off")
                                if !observation.sensor_contract_verified || !observation.sensor_candidate_fresh {
                                    Text("Temperature reading is not verified for automatic heating safety checks.")
                                        .font(.caption).foregroundStyle(.red)
                                }
                            } else {
                                Text("Room temperature and live Homely state are not connected.")
                                    .font(.caption).foregroundStyle(.blue)
                            }
                            if let error = control.error { Text(error).foregroundStyle(.red) }
                            if !control.blockers.isEmpty {
                                Text("Further supervised checks are required before automatic heating can start.")
                                    .font(.caption).foregroundStyle(.blue)
                            }
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            GroupBox("Connection") {
                VStack(spacing: 12) {
                    TextField("https://heating.example.com", text: $address)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                        .accessibilityIdentifier("heating-controller-address").disabled(busy)
                    SecureField("Controller key", text: $token)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("heating-controller-key").disabled(busy)
                    Button("Connect / reload controller policy") { Task { await load() } }
                        .buttonStyle(.borderedProminent).disabled(busy)
                }.textFieldStyle(.roundedBorder)
            }
            if let document {
                GroupBox("Heating price policy") {
                    VStack(spacing: 12) {
                        policyPicker("Heating on", text: $onPrice, range: 1...20, unit: "p/kWh")
                        policyPicker("Heating off", text: $offPrice, range: 1...20, unit: "p/kWh")
                        policyPicker("Target temp", text: $target, range: 10...25, unit: "°C")
                        policyPicker("Temp ceiling", text: $limit, range: 10...25, unit: "°C")
                        Text("On at or below; off above. Hold the decision between prices.")
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
                    let current: ControllerStatus = try await api().request("status")
                    guard !current.control_enabled, current.mode == "plan_only" else {
                        status = nil; message = "Controller is outside plan-only mode."; messageIsError = true; return
                    }
                    status = current; checkedAt = Date()
                } catch {
                    if Task.isCancelled { return }
                    status = nil; message = "Controller status could not be refreshed. Last display is not a live heating state."; messageIsError = true
                }
            }
        }
        .task {
            if token.isEmpty { token = ControllerKeychain.read(address) }
            if !address.isEmpty, token.count >= 32, document == nil { await load() }
        }
        .onChange(of: address) { _, value in
            document = nil; status = nil; connectedAddress = nil
            token = ControllerKeychain.read(value); message = nil
        }
        .onChange(of: token) { _, _ in
            document = nil; status = nil; connectedAddress = nil; checkedAt = nil
        }
        .confirmationDialog("Save this heating policy to the controller?", isPresented: $confirmSave, titleVisibility: .visible) {
            Button("Save policy (automatic control stays disabled)") { Task { await save() } }
        } message: {
            Text("On at or below \(onPrice)p; off above \(offPrice)p. Target \(target)°C; limit \(limit)°C. This does not enable heating controls.")
        }
    }
    private func heatingStateLine(_ title: String, isOn: Bool?, identifier: String) -> some View {
        let value = isOn.map { $0 ? "ON" : "OFF" } ?? "unavailable"
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
        guard token.count >= 32 else { throw ControllerFailure.message("Enter your controller key (at least 32 characters).") }
        return ControllerAPI(base: try ControllerAPI.endpoint(address), token: token)
    }
    @MainActor private func load() async {
        busy = true; message = nil; messageIsError = false; document = nil; status = nil
        defer { busy = false }
        let original = address
        let originalToken = token
        do {
            let api = try api()
            let loaded: PolicyDocument = try await api.request("policy")
            let current: ControllerStatus = try await api.request("status")
            guard original == address, originalToken == token else { return }
            guard !current.control_enabled, current.mode == "plan_only" else {
                throw ControllerFailure.message("This app version only connects to controllers with live heating disabled.")
            }
            try ControllerKeychain.save(token, host: address)
            document = loaded; status = current; checkedAt = Date(); connectedAddress = address
            onPrice = String(loaded.policy.on_price_p); offPrice = String(loaded.policy.off_price_p)
            target = String(loaded.policy.target_c); limit = String(loaded.policy.limit_c)
        } catch { message = error.localizedDescription; messageIsError = true }
    }
    private func numeric(_ text: String) throws -> Double {
        guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")), value.isFinite else {
            throw ControllerFailure.message("Enter finite numbers for prices and temperatures.")
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
            draft.policy.target_c = try numeric(target); draft.policy.limit_c = try numeric(limit)
            guard draft.policy.off_price_p >= draft.policy.on_price_p,
                  5 <= draft.policy.target_c, draft.policy.target_c <= draft.policy.limit_c, draft.policy.limit_c <= 25 else {
                throw ControllerFailure.message("Off price must be at least on price. Require 5 ≤ target ≤ limit ≤ 25°C.")
            }
            let api = try api()
            let result: PolicyDocument = try await api.request("policy", body: draft)
            guard original == address, originalToken == token else { return }
            document = result; status = nil
            message = "Policy saved to controller. Automatic control remains disabled. Reload shortly for refreshed prices."
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
