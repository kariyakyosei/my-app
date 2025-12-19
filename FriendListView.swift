import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth
import Kingfisher

// FriendListViewModelは変更なし（そのまま使うか、必要なら前回のを参照）
// ここではView部分のみ修正して提示しますが、ViewModelも必要な場合は前回のコードと組み合わせてください。
// (念のためViewModelも含めた完全版を貼っておきます)

class FriendListViewModel: ObservableObject {
    @Published var friends: [User] = []
    
    func fetchFriends() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        db.collection("friendships").whereField("followerID", isEqualTo: uid).getDocuments { snapshot, _ in
            let followingIDs = snapshot?.documents.compactMap { $0["followingID"] as? String } ?? []
            if followingIDs.isEmpty { self.friends = []; return }
            self.friends = []
            for id in followingIDs {
                db.collection("users").document(id).getDocument { userSnapshot, _ in
                    if let user = try? userSnapshot?.data(as: User.self) {
                        DispatchQueue.main.async { self.friends.append(user) }
                    }
                }
            }
        }
    }
}

struct FriendListView: View {
    @StateObject private var viewModel = FriendListViewModel()
    @State private var showSearch = false
    
    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.friends.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.2.slash")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("まだフレンドはいません")
                            .foregroundColor(.gray)
                        
                        Button("友達を探す") { showSearch = true }
                            .foregroundColor(.accentColor) // 🌙 テーマカラー
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // 画面いっぱいに広げる
                    .background(Color(UIColor.systemBackground)) // 🌙
                } else {
                    List(viewModel.friends) { user in
                        NavigationLink(destination: UserProfileView(
                            targetUserID: user.uid,
                            targetUsername: user.username
                        )) {
                            HStack(spacing: 12) {
                                if let url = user.profileImageUrl, !url.isEmpty {
                                    KFImage(URL(string: url))
                                        .resizable().scaledToFill().frame(width: 44, height: 44).clipShape(Circle())
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .resizable().frame(width: 44, height: 44).foregroundColor(.gray)
                                }
                                Text(user.username)
                                    .font(.headline)
                                    .foregroundColor(.primary) // 🌙
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color(UIColor.systemBackground)) // 🌙
                    }
                    .listStyle(PlainListStyle())
                    .background(Color(UIColor.systemBackground)) // 🌙
                }
            }
            .background(Color(UIColor.systemBackground)) // 🌙 親VStackにも背景
            .navigationTitle("フレンド")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSearch = true }) {
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .navigationDestination(isPresented: $showSearch) {
                UserSearchView()
            }
            .onAppear { viewModel.fetchFriends() }
        }
    }
}
