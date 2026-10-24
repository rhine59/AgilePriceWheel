import SwiftUI

struct SwipeDashboardView: View {
    @EnvironmentObject private var model: AgileViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @StateObject private var solarModel = SolarForecastModel()
    @StateObject private var appSettings = AppSettingsStore()

    @State private var page: DashboardPage = .prices
    @State private var showingDocumentation = false
    @State private var nowRefreshID = UUID()

    var body: some View {
        ZStack {
            switch page {
            case .prices:
                pricesScreen
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
            case .savings:
                savingsScreen
                    .transition(.opacity)
            case .heating:
                heatingScreen
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
                    .minimumScaleFactor(0.56)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .background(Color(red: 0.012, green: 0.105, blue: 0.175))
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 68)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 10)
                    .allowsHitTesting(false)
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
        .onChange(of: appSettings.hasPVPanelsInstalled) { _, installed in
            guard !installed else { return }
            if page.isPVDependent {
                withAnimation { page = .solar }
            }
        }
        .sheet(isPresented: $showingDocumentation) {
            DocumentationView().preferredColorScheme(.dark)
        }
    }

    private var contentHorizontalPadding: CGFloat {
        horizontalSizeClass == .regular ? 24 : 14
    }

    private var contentMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? 760 : 680
    }

    private var bottomNavigation: some View {
        ViewThatFits(in: .horizontal) {
            navigationStrip(showLabels: true, compact: false)
            navigationStrip(showLabels: true, compact: true)
            navigationStrip(showLabels: false, compact: true)
        }
        .padding(.horizontal, horizontalSizeClass == .regular ? 12 : 3)
        .padding(.top, 5)
        .padding(.bottom, 5)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.orange.opacity(0.22))
                .frame(height: 1)
        }
        .animation(.easeInOut(duration: 0.18), value: appSettings.hasPVPanelsInstalled)
    }

    private func navigationStrip(showLabels: Bool, compact: Bool) -> some View {
        HStack(spacing: compact ? 0 : 2) {
            navigationButton(.prices, title: "Prices", systemImage: "bolt.circle.fill", showLabel: showLabels, compact: compact)
            navigationButton(.solar, title: "Solar", systemImage: "sun.max.fill", showLabel: showLabels, compact: compact)

            if appSettings.hasPVPanelsInstalled {
                navigationButton(.generation, title: "PV", systemImage: "bolt.fill", showLabel: showLabels, compact: compact)
                navigationButton(.netPrice, title: "Net", systemImage: "sterlingsign.circle.fill", showLabel: showLabels, compact: compact)
                navigationButton(.savings, title: "Save", systemImage: "banknote.fill", showLabel: showLabels, compact: compact)
            }

            navigationButton(.heating, title: "Heating", systemImage: "thermometer.medium", showLabel: showLabels, compact: compact)
            navigationButton(.settings, title: "Settings", systemImage: "slider.horizontal.3", showLabel: showLabels, compact: compact)
            navigationButton(.guide, title: "Guide", systemImage: "book.closed.fill", showLabel: showLabels, compact: compact)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func navigationButton(
        _ target: DashboardPage,
        title: String,
        systemImage: String,
        showLabel: Bool,
        compact: Bool
    ) -> some View {
        Button {
            withAnimation { page = target }
        } label: {
            VStack(spacing: compact ? 2 : 3) {
                Image(systemName: systemImage)
                    .font(.system(size: compact ? 17 : 19, weight: .semibold))
                    .frame(height: 22)

                if showLabel {
                    Text(title)
                        .font(.system(size: compact ? 8 : 9, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, compact ? 1 : 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(page == target ? Color.orange : Color.white.opacity(0.62))
        .accessibilityLabel(title == "Save" ? "Cost Savings" : title)
        .accessibilityAddTraits(page == target ? .isSelected : [])
    }

    private var nowButton: some View {
        Button {
            Task { await showNow() }
        } label: {
            Label("Now", systemImage: "clock.fill")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .lineLimit(1)
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

    private var metricNowRow: some View {
        HStack {
            Spacer(minLength: 0)
            nowButton
        }
        .frame(maxWidth: .infinity)
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

    private var pricesScreen: some View {
        ContentView()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                metricNowRow
                    .padding(.horizontal, contentHorizontalPadding)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.012, green: 0.105, blue: 0.175).opacity(0.96))
            }
    }

    private var solarScreen: some View {
        standardMetricScreen(title: "Solar Forecast") {
            SolarForecastView(
                model: solarModel,
                selectedDate: model.selectedDate,
                openSettings: { withAnimation { page = .settings } }
            )
        }
    }

    private var generationScreen: some View {
        standardMetricScreen(title: "PV Forecast") {
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
    }

    private var netPriceScreen: some View {
        standardMetricScreen(title: "Net Electricity Price") {
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
    }

    private var heatingScreen: some View {
        ZStack {
            dashboardBackground
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    pageHeader(title: "Heating Controller", subtitle: "Synology · current status", icon: "gearshape") {
                        withAnimation { page = .settings }
                    }
                    HeatingControllerView(agileModel: model, solarModel: solarModel, settings: appSettings)
                }
                .frame(maxWidth: contentMaxWidth)
                .padding(.horizontal, contentHorizontalPadding)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity)
            }
        }.preferredColorScheme(.dark)
    }

    private var savingsScreen: some View {
        standardMetricScreen(title: "Cost Savings") {
            ZStack {
                CostSavingsView(
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
                        title: "Cost savings disabled",
                        message: "This wheel needs forecast PV generation. Turn on Solar PV panels installed in App Settings to use it."
                    )
                }
            }
        }
    }

    private func standardMetricScreen<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            dashboardBackground
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    pageHeader(title: title, subtitle: dayLabel, icon: "gearshape") {
                        withAnimation { page = .settings }
                    }
                    metricNowRow
                    content()
                }
                .frame(maxWidth: contentMaxWidth)
                .padding(.horizontal, contentHorizontalPadding)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var settingsScreen: some View {
        ZStack {
            dashboardBackground
            VStack(spacing: 8) {
                settingsHeader
                    .frame(maxWidth: contentMaxWidth)
                    .padding(.horizontal, contentHorizontalPadding)

                AppSettingsView(agileModel: model, solarModel: solarModel, settings: appSettings)
                    .frame(maxWidth: contentMaxWidth)
            }
            .frame(maxWidth: .infinity)
        }
        .preferredColorScheme(.dark)
    }

    private var settingsHeader: some View {
        ViewThatFits(in: .horizontal) {
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
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text("Tariff · site · PV array · optimiser load")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.orange.opacity(0.82))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer()

                documentationButton
            }

            VStack(spacing: 3) {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.orange)
                        .frame(width: 42, height: 42)
                    Spacer()
                    documentationButton
                }
                Text("App Settings")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                Text("Tariff · site · PV array · optimiser load")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.orange.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .padding(.top, 4)
    }

    private var guideScreen: some View {
        DocumentationView(
            showsDoneButton: false,
            navigationTitle: "User Guide"
        )
        .preferredColorScheme(.dark)
    }

    private func pageHeader(title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                settingsButton(icon: icon, action: action)
                Spacer(minLength: 8)
                headerTitle(title: title, subtitle: subtitle, titleSize: 28)
                Spacer(minLength: 8)
                documentationButton
            }

            VStack(spacing: 3) {
                HStack {
                    settingsButton(icon: icon, action: action)
                    Spacer()
                    documentationButton
                }
                headerTitle(title: title, subtitle: subtitle, titleSize: 24)
            }
        }
    }

    private func headerTitle(title: String, subtitle: String, titleSize: CGFloat) -> some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.system(size: titleSize, weight: .semibold, design: .rounded))
                .foregroundStyle(.orange)
                .minimumScaleFactor(0.62)
                .lineLimit(1)
            Text(subtitle)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.orange.opacity(0.85))
                .lineLimit(1)
        }
    }

    private func settingsButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.orange)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("App settings")
    }

    private var documentationButton: some View {
        Button { showingDocumentation = true } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 27, weight: .medium))
                .foregroundStyle(.orange)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Guide and documentation")
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
    case savings
    case heating
    case settings
    case guide

    var isPVDependent: Bool {
        switch self {
        case .generation, .netPrice, .savings:
            return true
        case .prices, .solar, .heating, .settings, .guide:
            return false
        }
    }
}
