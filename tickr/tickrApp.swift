//
//  tickrApp.swift
//  tickr
//
//  Created by Alex Morrison on 16/4/2026.
//

import SwiftUI
import UserNotifications

final class TickrAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            if let tabRawValue = response.notification.request.content.userInfo["targetTab"] as? String,
               let tab = AppTab(rawValue: tabRawValue) {
                AppNavigationState.shared.selectedTab = tab
            }

            if let eventID = response.notification.request.content.userInfo["eventID"] as? String {
                AppNavigationState.shared.pendingEventID = eventID
                AppNavigationState.shared.selectedTab = .calendar
            }

            completionHandler()
        }
    }
}

@main
struct tickrApp: App {
    @UIApplicationDelegateAdaptor(TickrAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
    }
}
