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
                    .transition(.move(edge: .leading))
            case .solar:
                solarScreen.transition(.move(edge: .trailing))
            case .generation:
                generationScreen.transition(.move(edge: .trailing))
            case .netPrice:
                netPriceScreen.transition(.move(edge: .trailing))
            case .settings:
                settingsScreen.transition(.move(edge: .trailing))
            case .guide:
                guideScreen.transition(.move(edge: .trailing))
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
                    Spacer()
                    HStack {
                        Spacer()
                        nowButton
                    }
                }
                .padding(.trailing, 18)
                .padding(.bottom, 74)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: page)
        .simultaneousGesture(horizontalSwipe)
        .task { await solarModel.loadForecast(for: model.selectedDate) }
        .onChange(of: model.selectedDate) { _, newDate in
            Task { await solarModel.loadForecast(for: newDate) }
        }
        .sheet(isPresented: $showingDocumentation) {
            DocumentationView().preferredColorScheme(.dark)
        }
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
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.orange.opacity(0.65), lineWidth: 1))
        .shadow(radius: 4)
        .accessibilityLabel("Show values for the current time")
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
                    pageDots
                }
                .padding(.horizontal, 16).padding(.bottom, 20)
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
                        GenerationEstimateView(solarModel: solarModel, settings: appSettings, selectedDate: model.selectedDate, openSettings: { withAnimation { page = .settings } })
                            .id(nowRefreshID)
                            .disabled(!appSettings.hasPVPanelsInstalled)
                            .opacity(appSettings.hasPVPanelsInstalled ? 1.0 : 0.24)
                        if !appSettings.hasPVPanelsInstalled {
                            pvDisabledOverlay(title: "PV forecast disabled", message: "Solar PV panels installed is turned off in App Settings.")
                        }
                    }
                    pageDots
                }
                .padding(.horizontal, 16).padding(.bottom, 20)
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
                        NetEffectivePriceView(agileModel: model, solarModel: solarModel, settings: appSettings, openSettings: { withAnimation { page = .settings } })
                            .id(nowRefreshID)
                            .disabled(!appSettings.hasPVPanelsInstalled)
                            .opacity(appSettings.hasPVPanelsInstalled ? 1.0 : 0.22)
                        if !appSettings.hasPVPanelsInstalled {
                            pvDisabledOverlay(title: "Net price disabled", message: "This wheel needs forecast PV generation. Turn on Solar PV panels installed in App Settings to use it.")
                        }
                    }
                    pageDots
                }
                .padding(.horizontal, 16).padding(.bottom, 20)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var settingsScreen: some View {
        ZStack {
            dashboardBackground
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "slider.horizontal.3").font(.system(size: 24, weight: .medium)).foregroundStyle(.orange).frame(width: 42, height: 42)
                    Spacer()
                    VStack(spacing: 1) {
                        Text("App Settings").font(.system(size: 28, weight: .semibold, design: .rounded)).foregroundStyle(.orange).minimumScaleFactor(0.75).lineLimit(1)
                        Text("Tariff · site · PV array · optimiser load").font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(.orange.opacity(0.82))
                    }
                    Spacer()
                    Button { showingDocumentation = true } label: {
                        Image(systemName: "info.circle").font(.system(size: 27, weight: .medium)).foregroundStyle(.orange).frame(width: 42, height: 42)
                    }.accessibilityLabel("Guide and documentation")
                }
                .padding(.horizontal, 16).padding(.top, 4)
                AppSettingsView(agileModel: model, solarModel: solarModel, settings: appSettings)
                HStack(spacing: 8) {
                    Text("Swipe right for Net Price"); Image(systemName: "arrow.left.and.right"); Text("left for User Guide")
                }.font(.caption2).foregroundStyle(.white.opacity(0.48)).padding(.horizontal, 12)
                pageDots.padding(.bottom, 8)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var guideScreen: some View {
        ZStack(alignment: .bottom) {
            DocumentationView(showsDoneButton: false, navigationTitle: "User Guide").preferredColorScheme(.dark)
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Text("Swipe right for Settings"); Image(systemName: "arrow.left.and.right"); Text("left to return to Prices")
                }.font(.caption2).foregroundStyle(.white.opacity(0.72))
                pageDots
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule()).padding(.bottom, 8)
        }
    }

    private func pageHeader(title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        HStack {
            Button(action: action) {
                Image(systemName: icon).font(.system(size: 26, weight: .medium)).foregroundStyle(.orange).frame(width: 42, height: 42)
            }.accessibilityLabel("App settings")
            Spacer()
            VStack(spacing: 1) {
                Text(title).font(.system(size: 28, weight: .semibold, design: .rounded)).foregroundStyle(.orange).minimumScaleFactor(0.72).lineLimit(1)
                Text(subtitle).font(.system(size: 15, weight: .medium, design: .rounded)).foregroundStyle(.orange.opacity(0.85))
            }
            Spacer()
            Button { showingDocumentation = true } label: {
                Image(systemName: "info.circle").font(.system(size: 27, weight: .medium)).foregroundStyle(.orange).frame(width: 42, height: 42)
            }.accessibilityLabel("Guide and documentation")
        }
    }

    private func pvDisabledOverlay(title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "sun.max.fill").font(.system(size: 34, weight: .medium))
            Text(title).font(.headline)
            Text(message).font(.caption).multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("Open App Settings") { withAnimation { page = .settings } }.buttonStyle(.bordered)
        }
        .foregroundStyle(.secondary).padding(18).frame(maxWidth: 330)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.gray.opacity(0.35), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private var dashboardBackground: some View {
        LinearGradient(colors: [Color(red: 0.01, green: 0.09, blue: 0.16), Color(red: 0.015, green: 0.13, blue: 0.21), Color(red: 0.01, green: 0.08, blue: 0.14)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
    }

    private var pageDots: some View {
        HStack(spacing: 7) { pageDot(.prices); pageDot(.solar); pageDot(.generation); pageDot(.netPrice); pageDot(.settings); pageDot(.guide) }
            .padding(.top, 2).accessibilityElement(children: .ignore).accessibilityLabel("Page \(page.accessibilityPosition) of 6")
    }

    private func pageDot(_ target: DashboardPage) -> some View {
        Circle().fill(page == target ? Color.orange : Color.white.opacity(0.28)).frame(width: 7, height: 7)
    }

    private var horizontalSwipe: some Gesture {
        DragGesture(minimumDistance: 60).onEnded { value in
            let horizontal = value.translation.width, vertical = value.translation.height
            guard abs(horizontal) > abs(vertical) * 1.35 else { return }
            if horizontal < -80 {
                switch page { case .prices: page = .solar; case .solar: page = .generation; case .generation: page = .netPrice; case .netPrice: page = .settings; case .settings: page = .guide; case .guide: page = .prices }
            } else if horizontal > 80 {
                switch page { case .prices: break; case .solar: page = .prices; case .generation: page = .solar; case .netPrice: page = .generation; case .settings: page = .netPrice; case .guide: page = .settings }
            }
        }
    }

    private var dayLabel: String {
        if Calendar.uk.isDateInToday(model.selectedDate) { return "Today" }
        if Calendar.uk.isDateInTomorrow(model.selectedDate) { return "Tomorrow" }
        return model.selectedDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }
}

private enum DashboardPage: Equatable {
    case prices, solar, generation, netPrice, settings, guide

    var isMetricsPage: Bool {
        switch self { case .prices, .solar, .generation, .netPrice: return true; case .settings, .guide: return false }
    }

    var accessibilityPosition: Int {
        switch self { case .prices: return 1; case .solar: return 2; case .generation: return 3; case .netPrice: return 4; case .settings: return 5; case .guide: return 6 }
    }
}
