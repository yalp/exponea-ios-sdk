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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    static let memoryLogger = MemoryLogger()
    var window: UIWindow?
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Exponea.logger = AppDelegate.memoryLogger
        Exponea.logger.logLevel = .verbose
        
        UITabBar.appearance().tintColor = UIColor(red: 28/255, green: 23/255, blue: 50/255, alpha: 1.0)
        
        application.applicationIconBadgeNumber = 0
        
        // Set exponea categories
        let categories = Exponea.shared.createNotificationCategories(openAppButtonTitle: "Open app",
                                                                     openBrowserButtonTitle: "Open browser",
                                                                     openDeeplinkButtonTitle: "Show item")
        UNUserNotificationCenter.current().setNotificationCategories(categories)
        
        return true
    }
}

extension AppDelegate {
    func showPushAlert(_ message: String?) {
        let alert = UIAlertController(title: "Push Notification Received", message: message ?? "no body", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        (window?.rootViewController as? UINavigationController)?.topViewController?.present(alert, animated: true, completion: nil)
        
        let alertWindow = UIWindow(frame: UIScreen.main.bounds)
        alertWindow.rootViewController = UIViewController()
        alertWindow.windowLevel = .alert + 1
        alertWindow.makeKeyAndVisible()
        alertWindow.rootViewController?.present(alert, animated: true, completion: nil)
    }
}

extension AppDelegate: PushNotificationManagerDelegate {
    func pushNotificationOpened(with action: ExponeaNotificationAction, value: String?, extraData: [AnyHashable : Any]?) {
        showPushAlert("Action \(action), value: \(String(describing: value)), extraData \(String(describing: extraData))")
    }
}
