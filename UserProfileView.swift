import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Kingfisher

struct UserProfileView: View {
    let targetUserID: String      // 相手のID
    let targetUsername: String    // 相手の名前
    
    @State private var userPosts: [Post] = [] // 相手の投稿
    @State private var friendCount: Int = 0   // 相手のフレンド数
    
    // フレンド状態管理用
    @State private var isFriend: Bool = false
    @State private var myUid: String = Auth.auth().currentUser?.uid ?? ""
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                // --- ヘッダーエリア ---
                HStack(spacing: 20) {
                    // 1. アイコン
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.gray)
                    
                    // 2. 数字データ
                    HStack(spacing: 30) {
                        // 投稿数
                        VStack {
                            Text("\(userPosts.count)")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("投稿")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        // フレンド数
                        VStack {
                            Text("\(friendCount)")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("フレンド")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // 3. 名前と自己紹介
                VStack(alignment: .leading, spacing: 5) {
                    Text(targetUsername)
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text("こんにちは！") // 仮の自己紹介
                        .font(.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // 4. フレンド登録/解除ボタン
                // (自分自身のページでなければ表示)
                if targetUserID != myUid {
                    Button(action: {
                        toggleFriend()
                    }) {
                        Text(isFriend ? "フレンド中" : "フレンド登録")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(isFriend ? Color.gray.opacity(0.2) : Color.accentColor)
                            .foregroundColor(isFriend ? .black : .white)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                }
                
                Divider()
                    .padding(.vertical, 5)
                
                // --- 投稿ギャラリー ---
                if userPosts.isEmpty {
                    Text("投稿がありません")
                        .foregroundColor(.gray)
                        .padding(.top, 50)
                } else {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(userPosts) { post in
                            KFImage(URL(string: post.imageUrl))
                                .resizable()
                                .scaledToFill()
                                .frame(width: UIScreen.main.bounds.width / 3 - 2, height: UIScreen.main.bounds.width / 3 - 2)
                                .clipped()
                        }
                    }
                }
            }
        }
        .navigationTitle(targetUsername)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            fetchData()
        }
    }
    
    // まとめてデータを取る
    func fetchData() {
        fetchUserPosts()
        fetchFriendCount()
        checkFriendStatus()
    }
    
    // 投稿取得
    func fetchUserPosts() {
        let db = Firestore.firestore()
        db.collection("posts")
            .whereField("photographerID", isEqualTo: targetUserID)
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    self.userPosts = snapshot?.documents.compactMap { try? $0.data(as: Post.self) } ?? []
                }
            }
    }
    
    // フレンド数取得
    func fetchFriendCount() {
        let db = Firestore.firestore()
        db.collection("friendships")
            .whereField("followerID", isEqualTo: targetUserID)
            .getDocuments { snapshot, _ in
                DispatchQueue.main.async {
                    self.friendCount = snapshot?.count ?? 0
                }
            }
    }
    
    // 自分がすでにフレンド登録しているかチェック
    func checkFriendStatus() {
        let db = Firestore.firestore()
        let docID = "\(myUid)_\(targetUserID)"
        
        db.collection("friendships").document(docID).getDocument { snapshot, _ in
            DispatchQueue.main.async {
                self.isFriend = snapshot?.exists ?? false
            }
        }
    }
    
    // フレンド登録/解除処理
    func toggleFriend() {
        let db = Firestore.firestore()
        let docID = "\(myUid)_\(targetUserID)"
        let ref = db.collection("friendships").document(docID)
        
        if isFriend {
            // 解除
            ref.delete { _ in
                isFriend = false
            }
        } else {
            // 登録
            let data: [String: Any] = [
                "followerID": myUid,
                "followingID": targetUserID,
                "timestamp": Timestamp(date: Date())
            ]
            ref.setData(data) { _ in
                isFriend = true
            }
        }
    }
}
