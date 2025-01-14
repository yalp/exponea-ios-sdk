//
//  AppDelegate.swift
//  Example
//
//  Created by Dominik Hadl on 01/05/2018.
//  Copyright © 2018 Exponea. All rights reserved.
//

import UIKit
import ExponeaSDK
import UserNotifications

// This protocol is used queried using reflection by native iOS SDK to see if SDK is used by our example app
@objc(IsExponeaExampleApp)
protocol IsExponeaExampleApp {
}

@UIApplicationMain
class AppDelegate: ExponeaAppDelegate {

    static let memoryLogger = MemoryLogger()
    var window: UIWindow?
    var alertWindow: UIWindow?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        super.application(application, didFinishLaunchingWithOptions: launchOptions)
        Exponea.logger = AppDelegate.memoryLogger
        Exponea.logger.logLevel = .verbose

        UITabBar.appearance().tintColor = UIColor(red: 28/255, green: 23/255, blue: 50/255, alpha: 1.0)
        UINavigationBar.appearance().backgroundColor = UIColor(red: 249/255, green: 249/255, blue: 249/255, alpha: 0.94)
        UIBarButtonItem.appearance().tintColor = UIColor(red: 248/255, green: 76/255, blue: 172/255, alpha: 1.0)
        UINavigationBar.appearance().titleTextAttributes = [
            NSAttributedString.Key.foregroundColor : UIColor(red: 248/255, green: 76/255, blue: 172/255, alpha: 1.0)
        ]

        application.applicationIconBadgeNumber = 0

        // Set legacy exponea categories
        let category1 = UNNotificationCategory(identifier: "EXAMPLE_LEGACY_CATEGORY_1",
                                              actions: [
            ExponeaNotificationAction.createNotificationAction(type: .openApp, title: "Hardcoded open app", index: 0),
            ExponeaNotificationAction.createNotificationAction(type: .deeplink, title: "Hardcoded deeplink", index: 1)
            ], intentIdentifiers: [], options: [])

        let category2 = UNNotificationCategory(identifier: "EXAMPLE_LEGACY_CATEGORY_2",
                                               actions: [
            ExponeaNotificationAction.createNotificationAction(type: .browser, title: "Hardcoded browser", index: 0)
            ], intentIdentifiers: [], options: [])

        UNUserNotificationCenter.current().setNotificationCategories([category1, category2])

        return true
    }

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let incomingURL = userActivity.webpageURL
            else { return false }
        Exponea.shared.trackCampaignClick(url: incomingURL, timestamp: nil)
        return incomingURL.host == "old.panaxeo.com"
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false), components.scheme == "exponea" {
            if let type = DeeplinkType(input: url.absoluteString) {
                DeeplinkManager.manager.setDeeplinkType(type: type)
            } else {
                showAlert("Deeplink received", url.absoluteString)
            }
            return true
        }
        return false
    }
}

extension AppDelegate {
    func showAlert(_ title: String, _ message: String?) {
        let alert = UIAlertController(title: title, message: message ?? "no body", preferredStyle: .alert)
        alert.addAction(
            UIAlertAction(
                title: "Ok",
                style: .default,
                handler: { [weak self] _ in self?.alertWindow?.isHidden = true }
            )
        )
        if alertWindow == nil {
            alertWindow = UIWindow(frame: UIScreen.main.bounds)
            alertWindow?.rootViewController = UIViewController()
            alertWindow?.windowLevel = .alert + 1
        }
        alertWindow?.makeKeyAndVisible()
        alertWindow?.rootViewController?.present(alert, animated: true, completion: nil)
    }
}

extension AppDelegate: PushNotificationManagerDelegate {
    func pushNotificationOpened(
        with action: ExponeaNotificationActionType,
        value: String?,
        extraData: [AnyHashable: Any]?
    ) {
        Exponea.logger.log(
            .verbose,
            message: "Alert push opened, " +
                "action \(action), value: \(String(describing: value)), extraData \(String(describing: extraData))"
        )
        showAlert(
            "Push notification opened",
            "action \(action), value: \(String(describing: value)), extraData \(String(describing: extraData))"
        )
    }

    func silentPushNotificationReceived(extraData: [AnyHashable: Any]?) {
        Exponea.logger.log(
            .verbose,
            message: "Silent push received, extraData \(String(describing: extraData))"
        )
        showAlert(
            "Silent push received",
            "extraData \(String(describing: extraData))"
        )
    }
}

class InAppDelegate: InAppMessageActionDelegate {
    let overrideDefaultBehavior: Bool
    let trackActions: Bool

    init(
        overrideDefaultBehavior: Bool,
        trackActions: Bool
    ) {
        self.overrideDefaultBehavior = overrideDefaultBehavior
        self.trackActions = trackActions
    }

    func inAppMessageAction(with message: InAppMessage, button: InAppMessageButton?, interaction: Bool) {
        Exponea.logger.log(
            .verbose,
            message: "In app action performed, messageId: \(message.id),"
            + " interaction: \(interaction), button: \(String(describing: button))"
        )
        (UIApplication.shared.delegate as? AppDelegate)?.showAlert(
            "In app action performed",
            "messageId: \(message.id), interaction: \(interaction), button: \(String(describing: button))"
        )

        if interaction {
            Exponea.shared.trackInAppMessageClick(message: message, buttonText: button?.text, buttonLink: button?.url)
        } else {
            Exponea.shared.trackInAppMessageClose(message: message, isUserInteraction: false)
        }
    }
}
