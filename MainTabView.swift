import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showFriendsOnly = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            
            // 1. フィード
            FeedView(showFriendsOnly: $showFriendsOnly)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("ホーム")
                }
                .tag(0)
            
            // 2. フレンド（または検索）
            FriendListView()
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("フレンド")
                }
                .tag(1)
            
            // 3. 投稿 (真ん中)
            PostView(selectedTab: $selectedTab, showFriendsOnly: $showFriendsOnly)
                .tabItem {
                    Image(systemName: "plus.app.fill")
                    Text("投稿")
                }
                .tag(2)
            
            // 4. プロフィール
            ProfileView()
                .tabItem {
                    Image(systemName: "person.crop.circle")
                    Text("マイページ")
                }
                .tag(3)
            
            // 🆕 5. 設定 (お知らせの代わりに追加！)
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("設定")
                }
                .tag(4)
        }
        .accentColor(.primary) // アイコンの色（ダークモード対応）
    }
}
