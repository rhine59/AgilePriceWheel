import SwiftUI

struct SwipeDashboardView: View {
    @EnvironmentObject private var model: AgileViewModel
    @StateObject private var solarModel = SolarForecastModel()
    @StateObject private var appSettings = AppSettingsStore()

    @State private var page: DashboardPage = .prices
    @State private var showingDocumentation = false
    @State private var nowRefreshID = UUID()

    var body: some View {
        ZStack {
            switch page {
            case .prices:
                ContentView()
                    .transition(.opacity)
            case .solar:
                solarScreen
                    .transition(.opacity)
            case .generation:
                generationScreen
                    .transition(.opacity)
            case .netPrice:
                netPriceScreen
                    .transition(.opacity)
            case .settings:
                settingsScreen
                    .transition(.opacity)
            case .guide:
                guideScreen
                    .transition(.opacity)
            }

            if page == .prices {
                Text("Octopus Agile Prices")
                    .font(.system(size: 27, weight: .semibold, design: .rounded))
                    .foregroundStyle(.orange)
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .background(Color(red: 0.012, green: 0.105, blue: 0.175))
                    .frame(maxWidth: 270)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 10)
                    .allowsHitTesting(false)
            }

            if page.isMetricsPage {
                VStack {
                    HStack {
                        Spacer()
                        nowButton
                    }
                    Spacer()
                }
                .padding(.top, nowButtonTopPadding)
                .padding(.trailing, 18)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: page)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomNavigation
        }
        .task { await solarModel.loadForecast(for: model.selectedDate) }
        .onChange(of: model.selectedDate) { _, newDate in
            Task { await solarModel.loadForecast(for: newDate) }
        }
        .sheet(isPresented: $showingDocumentation) {
            DocumentationView().preferredColorScheme(.dark)
        }
    }

    private var bottomNavigation: some View {
        HStack(spacing: 4) {
            navigationButton(.prices, title: "Prices", systemImage: "bolt.circle.fill")
            navigationButton(.solar, title: "Solar", systemImage: "sun.max.fill")
            navigationButton(.generation, title: "PV", systemImage: "bolt.sun.fill")
            navigationButton(.netPrice, title: "Net", systemImage: "sterlingsign.circle.fill")
            navigationButton(.settings, title: "Settings", systemImage: "slider.horizontal.3")
            navigationButton(.guide, title: "Guide", systemImage: "book.closed.fill")
        }
        .padding(.horizontal, 6)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.orange.opacity(0.22))
                .frame(height: 1)
        }
    }

    private func navigationButton(_ target: DashboardPage, title: String, systemImage: String) -> some View {
        Button {
            withAnimation { page = target }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 19, weight: .semibold))
                Text(title)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .foregroundStyle(page == target ? Color.orange : Color.white.opacity(0.62))
        .accessibilityLabel(title)
        .accessibilityAddTraits(page == target ? .isSelected : [])
    }

    private var nowButton: some View {
        Button {
            Task { await showNow() }
        } label: {
            Label("Now", systemImage: "clock.fill")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.orange)
        .background(Color.black.opacity(0.72), in: Capsule())
        .overlay(Capsule().stroke(Color.orange.opacity(0.65), lineWidth: 1))
        .shadow(radius: 4)
        .accessibilityLabel("Show values for the current time")
    }

    private var nowButtonTopPadding: CGFloat {
        switch page {
        case .prices:
            return 92
        case .solar, .generation, .netPrice:
            return 86
        case .settings, .guide:
            return 0
        }
    }

    @MainActor
    private func showNow() async {
        let now = Date()
        let dateWasToday = Calendar.uk.isDateInToday(model.selectedDate)
        model.selectedDate = now

        if !dateWasToday || model.rates.isEmpty {
            await model.loadRates()
        }
        if !dateWasToday || solarModel.forecast.isEmpty {
            await solarModel.loadForecast(for: now)
        }

        model.selectedRateID = model.rates.first(where: { $0.validFrom <= now && now < $0.validTo })?.id
            ?? model.rates.first?.id
        solarModel.selectedSolarID = solarModel.forecast.first(where: { $0.validFrom <= now && now < $0.validTo })?.id
            ?? solarModel.forecast.first?.id

        nowRefreshID = UUID()
    }

    private var solarScreen: some View {
        ZStack {
            dashboardBackground
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    pageHeader(title: "Solar Forecast", subtitle: dayLabel, icon: "gearshape") { withAnimation { page = .settings } }
                    SolarForecastView(model: solarModel, selectedDate: model.selectedDate, openSettings: { withAnimation { page = .settings } })
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var generationScreen: some View {
        ZStack {
            dashboardBackground
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    pageHeader(title: "PV Forecast", subtitle: dayLabel, icon: "gearshape") { withAnimation { page = .settings } }
                    ZStack {
                        GenerationEstimateView(
                            solarModel: solarModel,
                            settings: appSettings,
                            selectedDate: model.selectedDate,
                            openSettings: { withAnimation { page = .settings } }
                        )
                        .id(nowRefreshID)
                        .disabled(!appSettings.hasPVPanelsInstalled)
                        .opacity(appSettings.hasPVPanelsInstalled ? 1.0 : 0.24)

                        if !appSettings.hasPVPanelsInstalled {
                            pvDisabledOverlay(
                                title: "PV forecast disabled",
                                message: "Solar PV panels installed is turned off in App Settings."
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var netPriceScreen: some View {
        ZStack {
            dashboardBackground
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    pageHeader(title: "Net Electricity Price", subtitle: dayLabel, icon: "gearshape") { withAnimation { page = .settings } }
                    ZStack {
                        NetEffectivePriceView(
                            agileModel: model,
                            solarModel: solarModel,
                            settings: appSettings,
                            openSettings: { withAnimation { page = .settings } }
                        )
                        .id(nowRefreshID)
                        .disabled(!appSettings.hasPVPanelsInstalled)
                        .opacity(appSettings.hasPVPanelsInstalled ? 1.0 : 0.22)

                        if !appSettings.hasPVPanelsInstalled {
                            pvDisabledOverlay(
                                title: "Net price disabled",
                                message: "This wheel needs forecast PV generation. Turn on Solar PV panels installed in App Settings to use it."
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var settingsScreen: some View {
        ZStack {
            dashboardBackground
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.orange)
                        .frame(width: 42, height: 42)

                    Spacer()

                    VStack(spacing: 1) {
                        Text("App Settings")
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .foregroundStyle(.orange)
                            .minimumScaleFactor(0.75)
                            .lineLimit(1)
                        Text("Tariff · site · PV array · optimiser load")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.orange.opacity(0.82))
                    }

                    Spacer()

                    Button { showingDocumentation = true } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 27, weight: .medium))
                            .foregroundStyle(.orange)
                            .frame(width: 42, height: 42)
                    }
                    .accessibilityLabel("Guide and documentation")
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)

                AppSettingsView(agileModel: model, solarModel: solarModel, settings: appSettings)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var guideScreen: some View {
        DocumentationView(
            showsDoneButton: false,
            navigationTitle: "User Guide"
        )
        .preferredColorScheme(.dark)
    }

    private func pageHeader(title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        HStack {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.orange)
                    .frame(width: 42, height: 42)
            }
            .accessibilityLabel("App settings")

            Spacer()

            VStack(spacing: 1) {
                Text(title)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.orange)
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.orange.opacity(0.85))
            }

            Spacer()

            Button { showingDocumentation = true } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 27, weight: .medium))
                    .foregroundStyle(.orange)
                    .frame(width: 42, height: 42)
            }
            .accessibilityLabel("Guide and documentation")
        }
    }

    private func pvDisabledOverlay(title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 34, weight: .medium))
            Text(title)
                .font(.headline)
            Text(message)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Open App Settings") {
                withAnimation { page = .settings }
            }
            .buttonStyle(.bordered)
        }
        .foregroundStyle(.secondary)
        .padding(18)
        .frame(maxWidth: 330)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.gray.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private var dashboardBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.01, green: 0.09, blue: 0.16),
                Color(red: 0.015, green: 0.13, blue: 0.21),
                Color(red: 0.01, green: 0.08, blue: 0.14)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var dayLabel: String {
        if Calendar.uk.isDateInToday(model.selectedDate) { return "Today" }
        if Calendar.uk.isDateInTomorrow(model.selectedDate) { return "Tomorrow" }
        return model.selectedDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }
}

private enum DashboardPage: Equatable {
    case prices
    case solar
    case generation
    case netPrice
    case settings
    case guide

    var isMetricsPage: Bool {
        switch self {
        case .prices, .solar, .generation, .netPrice:
            return true
        case .settings, .guide:
            return false
        }
    }
}
