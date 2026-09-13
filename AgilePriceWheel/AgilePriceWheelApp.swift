import SwiftUI

@main
struct AgilePriceWheelApp: App {
    @StateObject private var model = AgileViewModel()

    var body: some Scene {
        WindowGroup {
            SwipeDashboardView()
                .environmentObject(model)
        }
    }
}
