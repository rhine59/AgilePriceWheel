import SwiftUI

struct SwipeDashboardView: View {
    @EnvironmentObject private var model: AgileViewModel
    @StateObject private var solarModel = SolarForecastModel()
    @StateObject private var appSettings = AppSettingsStore()

    @State private var page: DashboardPage = .prices
    @State private var showingDocumentation = false

    var body: some View {
        ZStack {
            switch page {
            case .prices:
                ContentView()
                    .transition(.move(edge: .leading))
            case .solar:
                solarScreen
                    .transition(.move(edge: .trailing))
            case .settings:
                settingsScreen
                    .transition(.move(edge: .trailing))
            case .generation:
                generationScreen
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: page)
        .simultaneousGesture(horizontalSwipe)
        .task {
            await solarModel.loadForecast(for: model.selectedDate)
        }
        .onChange(of: model.selectedDate) { _, newDate in
            Task { await solarModel.loadForecast(for: newDate) }
        }
        .sheet(isPresented: $showingDocumentation) {
            DocumentationView()
                .preferredColorScheme(.dark)
        }
    }

    private var solarScreen: some View {
        ZStack {
            dashboardBackground

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    HStack {
                        Button {
                            withAnimation { page = .settings }
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 26, weight: .medium))
                                .foregroundStyle(.orange)
                                .frame(width: 42, height: 42)
                        }
                        .accessibilityLabel("App settings")

                        Spacer()

                        VStack(spacing: 1) {
                            Text("Solar Forecast")
                                .font(.system(size: 28, weight: .semibold, design: .rounded))
                                .foregroundStyle(.orange)
                                .minimumScaleFactor(0.75)
                                .lineLimit(1)
                            Text(dayLabel)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(.orange.opacity(0.85))
                        }

                        Spacer()

                        Button {
                            showingDocumentation = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 27, weight: .medium))
                                .foregroundStyle(.orange)
                                .frame(width: 42, height: 42)
                        }
                        .accessibilityLabel("Guide and documentation")
                    }

                    SolarForecastView(
                        model: solarModel,
                        selectedDate: model.selectedDate,
                        openSettings: { withAnimation { page = .settings } }
                    )

                    pageDots
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
                        Text("Tariff · site · solar PV array")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.orange.opacity(0.82))
                    }

                    Spacer()

                    Button {
                        showingDocumentation = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 27, weight: .medium))
                            .foregroundStyle(.orange)
                            .frame(width: 42, height: 42)
                    }
                    .accessibilityLabel("Guide and documentation")
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)

                AppSettingsView(
                    agileModel: model,
                    solarModel: solarModel,
                    settings: appSettings
                )

                HStack(spacing: 8) {
                    Text("Swipe right for Solar Forecast")
                    Image(systemName: "arrow.left.and.right")
                    Text("left for Generation")
                }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.48))
                .padding(.horizontal, 12)

                pageDots
                    .padding(.bottom, 8)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var generationScreen: some View {
        ZStack {
            dashboardBackground

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    HStack {
                        Button {
                            withAnimation { page = .settings }
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 26, weight: .medium))
                                .foregroundStyle(.orange)
                                .frame(width: 42, height: 42)
                        }
                        .accessibilityLabel("App settings")

                        Spacer()

                        VStack(spacing: 1) {
                            Text("PV Generation")
                                .font(.system(size: 28, weight: .semibold, design: .rounded))
                                .foregroundStyle(.orange)
                                .minimumScaleFactor(0.75)
                                .lineLimit(1)
                            Text(dayLabel)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(.orange.opacity(0.85))
                        }

                        Spacer()

                        Button {
                            showingDocumentation = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 27, weight: .medium))
                                .foregroundStyle(.orange)
                                .frame(width: 42, height: 42)
                        }
                        .accessibilityLabel("Guide and documentation")
                    }

                    GenerationEstimateView(
                        solarModel: solarModel,
                        settings: appSettings,
                        selectedDate: model.selectedDate,
                        openSettings: { withAnimation { page = .settings } }
                    )

                    pageDots
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .preferredColorScheme(.dark)
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

    private var pageDots: some View {
        HStack(spacing: 7) {
            pageDot(.prices)
            pageDot(.solar)
            pageDot(.settings)
            pageDot(.generation)
        }
        .padding(.top, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(page.accessibilityPosition) of 4")
    }

    private func pageDot(_ target: DashboardPage) -> some View {
        Circle()
            .fill(page == target ? Color.orange : Color.white.opacity(0.28))
            .frame(width: 7, height: 7)
    }

    private var horizontalSwipe: some Gesture {
        DragGesture(minimumDistance: 60)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > abs(vertical) * 1.35 else { return }

                if horizontal < -80 {
                    switch page {
                    case .prices:
                        page = .solar
                    case .solar:
                        page = .settings
                    case .settings:
                        page = .generation
                    case .generation:
                        break
                    }
                } else if horizontal > 80 {
                    switch page {
                    case .prices:
                        break
                    case .solar:
                        page = .prices
                    case .settings:
                        page = .solar
                    case .generation:
                        page = .settings
                    }
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
    case prices
    case solar
    case settings
    case generation

    var accessibilityPosition: Int {
        switch self {
        case .prices: return 1
        case .solar: return 2
        case .settings: return 3
        case .generation: return 4
        }
    }
}
