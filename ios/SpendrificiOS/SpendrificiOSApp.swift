import SwiftUI

@main
struct SpendrificiOSApp: App {
    var body: some Scene {
        WindowGroup {
            if UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
                DashboardView()
            } else {
                OnboardingView()
            }
        }
    }
} 