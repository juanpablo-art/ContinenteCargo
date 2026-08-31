//
//  ContinenteCargoApp.swift
//  ContinenteCargo
//

import SwiftUI
import UserNotifications
import UIKit
import FirebaseCore
import FirebaseMessaging

extension Notification.Name {
    static let apnsDeviceToken = Notification.Name("APNsDeviceTokenReceived")
    static let pushNotificationTapped = Notification.Name("PushNotificationTapped")
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Nav bar: fondo opaco en color surface para que el inline title (negro)
        // sea legible. shadowColor añade una línea/sombra sutil que hace que
        // el buscador (en el nav bar drawer) parezca flotar sobre el contenido.
        let black   = UIColor.black
        let surface = UIColor(red: 246/255, green: 248/255, blue: 251/255, alpha: 1)
        let shadow  = UIColor(red: 0, green: 0, blue: 0, alpha: 0.10)

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = surface
        appearance.shadowColor = shadow
        appearance.titleTextAttributes      = [.foregroundColor: black]
        appearance.largeTitleTextAttributes = [.foregroundColor: black]

        UINavigationBar.appearance().standardAppearance   = appearance
        UINavigationBar.appearance().compactAppearance    = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance

        // Buscador: fondo blanco para contrastar con el surface del nav bar
        UISearchTextField.appearance().backgroundColor = .white
        UISearchTextField.appearance().textColor = UIColor(red: 10/255, green: 37/255, blue: 64/255, alpha: 1)

        // Tab bar: fondo opaco para evitar el efecto Liquid Glass de iOS 26
        // que causa parpadeos de color y transparencias al cambiar de tab.
        let tabBar = UITabBarAppearance()
        tabBar.configureWithOpaqueBackground()
        tabBar.backgroundColor = surface
        tabBar.shadowColor = shadow

        UITabBar.appearance().standardAppearance   = tabBar
        UITabBar.appearance().scrollEdgeAppearance = tabBar

        // Firebase: configura el SDK y asigna el delegate para recibir el FCM token.
        FirebaseApp.configure()
        Messaging.messaging().delegate = self

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
        // Entrega el APNs token a Firebase para que lo intercambie por FCM token.
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("📱 [Push] Registration failed: \(error.localizedDescription)")
    }

    // MARK: - MessagingDelegate

    // Firebase llama aquí cada vez que genera o renueva el FCM token.
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        print("📱 [FCM] Token: \(fcmToken)")
        NotificationCenter.default.post(
            name: .apnsDeviceToken, object: nil, userInfo: ["token": fcmToken])
    }

    // MARK: - UNUserNotificationCenterDelegate

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
