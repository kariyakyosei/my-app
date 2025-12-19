// torimaApp.swift
// 中身をすべて消して、これを貼り付けてください

import SwiftUI
import FirebaseCore
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct torimaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // ★重要: キーの名前を "isAuthenticated" に統一します
    @AppStorage("isAuthenticated") var isAuthenticated: Bool = false
    
    var body: some Scene {
        WindowGroup {
            if isAuthenticated {
                MainTabView() // ログイン中
            } else {
                SignUpView() // ログアウト中
            }
        }
    }
}
