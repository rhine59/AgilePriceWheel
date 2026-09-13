import SwiftUI

struct SwipeDashboardView: View {
    @EnvironmentObject private var model: AgileViewModel
    @StateObject private var solarModel = SolarForecastModel()

    @State private var page: DashboardPage = .prices
    @State private var showingSolarSettings = false
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
        .sheet(isPresented: $showingSolarSettings) {
            SolarSiteSettingsView(
                solarModel: solarModel,
                selectedDate: model.selectedDate
            )
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showingDocumentation) {
            DocumentationView()
                .preferredColorScheme(.dark)
        }
    }

    private var solarScreen: some View {
        ZStack {
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

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    HStack {
                        Button {
                            showingSolarSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 26, weight: .medium))
                                .foregroundStyle(.orange)
                                .frame(width: 42, height: 42)
                        }
                        .accessibilityLabel("Solar site settings")

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
                        openSettings: { showingSolarSettings = true }
                    )

                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.white.opacity(0.28))
                            .frame(width: 7, height: 7)
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 7, height: 7)
                    }
                    .padding(.top, 2)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var horizontalSwipe: some Gesture {
        DragGesture(minimumDistance: 60)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > abs(vertical) * 1.35 else { return }

                if page == .prices && horizontal < -80 {
                    page = .solar
                } else if page == .solar && horizontal > 80 {
                    page = .prices
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
}
