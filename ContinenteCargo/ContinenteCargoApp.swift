//
//  ContinenteCargoApp.swift
//  ContinenteCargo
//

import SwiftUI
import UserNotifications
import UIKit

extension Notification.Name {
    static let apnsDeviceToken = Notification.Name("APNsDeviceTokenReceived")
    static let pushNotificationTapped = Notification.Name("PushNotificationTapped")
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .badge, .sound])
                if granted {
                    await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
                }
            } catch {
                print("📱 [Push] Permission error: \(error.localizedDescription)")
            }
        }
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02hhx", $0) }.joined()
        print("📱 [Push] Device token: \(token)")
        NotificationCenter.default.post(
            name: .apnsDeviceToken, object: nil, userInfo: ["token": token])
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("📱 [Push] Registration failed: \(error.localizedDescription)")
    }

    // Muestra la notificación aunque la app esté en primer plano
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .badge, .sound])
    }

    // Maneja el tap en la notificación
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("📱 [Push] Notificación abierta: \(userInfo)")
        NotificationCenter.default.post(name: .pushNotificationTapped, object: nil, userInfo: userInfo)
        completionHandler()
    }
}

@main
struct ContinenteCargoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
