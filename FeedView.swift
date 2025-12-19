import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth
import Kingfisher
import FirebaseStorage

// MARK: - ViewModel (変更なし)
// FeedView.swift の中にある FeedViewModel をこれに書き換えてください

class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var usernames: [String: String] = [:]
    @Published var userImages: [String: String] = [:]
    @Published var likedPostIds: Set<String> = []
    @Published var friendUserIds: Set<String> = []
    @Published var blockedUserIds: Set<String> = []
    
    @Published var isLoading = false
    private var lastDocument: DocumentSnapshot? = nil
    private let limit = 10
    
    private var likeListener: ListenerRegistration?
    private var friendListener: ListenerRegistration?
    
    init() {
        startLikeMonitoring()
        startFriendMonitoring()
        fetchBlockedUsersAndRefresh()
        
        // 🆕 ブロックリスト変更通知を受け取る設定
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBlockListUpdate),
            name: .blockListDidUpdate,
            object: nil
        )
    }
    
    // 🆕 通知が来たら実行されるメソッド
    @objc func handleBlockListUpdate() {
        // ブロックリストを再取得して、フィードを更新する
        fetchBlockedUsersAndRefresh()
    }
    
    func fetchBlockedUsersAndRefresh() {
        BlockService.shared.fetchBlockedUsers { [weak self] ids in
            DispatchQueue.main.async {
                self?.blockedUserIds = Set(ids)
                // ブロックリスト更新後に、投稿を再取得（これで解除した人の投稿が復活します）
                self?.refreshPosts()
            }
        }
    }
    
    func refreshPosts() {
        isLoading = true
        lastDocument = nil
        let db = Firestore.firestore()
        db.collection("posts").order(by: "createdAt", descending: true).limit(to: limit)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false
                guard let documents = snapshot?.documents else { return }
                self.lastDocument = documents.last
                let allPosts = documents.compactMap { try? $0.data(as: Post.self) }
                // フィルタリングして表示
                self.posts = allPosts.filter { !self.blockedUserIds.contains($0.photographerID) }
            }
    }
    
    func loadMorePosts() {
        guard !isLoading, let lastDoc = lastDocument else { return }
        isLoading = true
        let db = Firestore.firestore()
        db.collection("posts").order(by: "createdAt", descending: true).start(afterDocument: lastDoc).limit(to: limit)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false
                guard let documents = snapshot?.documents, !documents.isEmpty else { return }
                self.lastDocument = documents.last
                let newPosts = documents.compactMap { try? $0.data(as: Post.self) }
                // フィルタリングして追加
                let filteredNewPosts = newPosts.filter { !self.blockedUserIds.contains($0.photographerID) }
                self.posts.append(contentsOf: filteredNewPosts)
            }
    }
    
    func blockUser(userID: String) {
        BlockService.shared.blockUser(targetUserID: userID) { [weak self] error in
            if error == nil {
                // NotificationCenter経由で更新されるので、ここの手動更新は削除しても良いですが
                // 即時反映のために残しておいても害はありません
            }
        }
    }
    
    func reportPost(post: Post, reason: String) {
        guard let postID = post.id else { return }
        BlockService.shared.reportPost(postID: postID, targetUserID: post.photographerID, reason: reason) { _ in }
    }
    
    // --- 以下変更なし ---
    
    func fetchUserInfo(for uid: String) {
        if usernames[uid] != nil && userImages[uid] != nil { return }
        Firestore.firestore().collection("users").document(uid).getDocument { [weak self] snapshot, _ in
            guard let self = self, let data = snapshot?.data() else { return }
            DispatchQueue.main.async {
                self.usernames[uid] = data["username"] as? String ?? "名無し"
                self.userImages[uid] = data["profileImageUrl"] as? String ?? ""
            }
        }
    }
    
    func startLikeMonitoring() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        likeListener = Firestore.firestore().collection("likes").whereField("userID", isEqualTo: uid).addSnapshotListener { [weak self] snapshot, _ in
            let ids = snapshot?.documents.compactMap { $0["postID"] as? String } ?? []
            DispatchQueue.main.async { self?.likedPostIds = Set(ids) }
        }
    }
    
    func startFriendMonitoring() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        friendListener = Firestore.firestore().collection("friendships").whereField("followerID", isEqualTo: uid).addSnapshotListener { [weak self] snapshot, _ in
            let ids = snapshot?.documents.compactMap { $0["followingID"] as? String } ?? []
            DispatchQueue.main.async { self?.friendUserIds = Set(ids) }
        }
    }
    
    func toggleLike(post: Post) {
        guard let postID = post.id, let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let likeRef = db.collection("likes").document("\(uid)_\(postID)")
        if likedPostIds.contains(postID) {
            likeRef.delete()
            db.collection("posts").document(postID).updateData(["likesCount": FieldValue.increment(Int64(-1))])
        } else {
            likeRef.setData(["userID": uid, "postID": postID, "timestamp": Date()])
            db.collection("posts").document(postID).updateData(["likesCount": FieldValue.increment(Int64(1))])
            sendNotification(to: post.photographerID, type: "like", post: post)
        }
    }
    
    func toggleFriend(targetUserID: String) {
        guard let myUid = Auth.auth().currentUser?.uid, targetUserID != myUid else { return }
        let db = Firestore.firestore()
        let docID = "\(myUid)_\(targetUserID)"
        if friendUserIds.contains(targetUserID) {
            db.collection("friendships").document(docID).delete()
        } else {
            let data: [String: Any] = ["followerID": myUid, "followingID": targetUserID, "timestamp": Timestamp(date: Date())]
            db.collection("friendships").document(docID).setData(data)
            sendNotification(to: targetUserID, type: "friend", post: nil)
        }
    }
    
    func deletePost(post: Post) {
        guard let postID = post.id, let uid = Auth.auth().currentUser?.uid else { return }
        guard post.photographerID == uid else { return }
        let storageRef = Storage.storage().reference(forURL: post.imageUrl)
        storageRef.delete { _ in
            Firestore.firestore().collection("posts").document(postID).delete { error in
                if error == nil {
                    DispatchQueue.main.async { self.posts.removeAll { $0.id == postID } }
                }
            }
        }
    }
    
    private func sendNotification(to receiverID: String, type: String, post: Post?) {
        guard let myUid = Auth.auth().currentUser?.uid, receiverID != myUid else { return }
        let db = Firestore.firestore()
        db.collection("users").document(myUid).getDocument { snapshot, _ in
            guard let data = snapshot?.data() else { return }
            let myName = data["username"] as? String ?? "名無し"
            let myIcon = data["profileImageUrl"] as? String ?? ""
            let notificationData: [String: Any] = [
                "type": type, "receiverID": receiverID, "senderID": myUid, "senderUsername": myName, "senderIconUrl": myIcon,
                "postID": post?.id ?? "", "postImageUrl": post?.imageUrl ?? "", "message": "", "createdAt": Timestamp(date: Date())
            ]
            db.collection("notifications").addDocument(data: notificationData)
        }
    }
}
// MARK: - Main View
struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @Binding var showFriendsOnly: Bool
    
    // アラート管理用の変数
    @State private var menuTargetPost: Post?
    @State private var showBlockAlert = false
    @State private var showReportAlert = false
    
    var filteredPosts: [Post] {
        if showFriendsOnly {
            return viewModel.posts.filter { viewModel.friendUserIds.contains($0.photographerID) }
        } else {
            return viewModel.posts
        }
    }
    
    // FeedViewの body の .navigationTitle の下あたりを修正します
    
    // (前略... FeedViewの構造体の中身)
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ... (PickerやScrollViewなどの中身は変更なし) ...
                Picker("表示モード", selection: $showFriendsOnly) {
                    Text("みんな").tag(false)
                    Text("フレンド").tag(true)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .background(Color(UIColor.systemBackground))
                
                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(filteredPosts, id: \.id) { post in
                            FeedPostRow(
                                post: post,
                                viewModel: viewModel,
                                onReport: {
                                    self.menuTargetPost = post
                                    self.showReportAlert = true
                                },
                                onBlock: {
                                    self.menuTargetPost = post
                                    self.showBlockAlert = true
                                }
                            )
                            .onAppear {
                                if post.id == viewModel.posts.last?.id {
                                    viewModel.loadMorePosts()
                                }
                            }
                        }
                        if viewModel.isLoading { ProgressView().padding() }
                    }
                    .padding(.top, 10).padding(.bottom, 20)
                }
                .refreshable { viewModel.refreshPosts() }
                .background(Color(UIColor.systemGroupedBackground))
            }
            .navigationTitle("フィード")
            .navigationBarTitleDisplayMode(.inline)
            
            // 🆕 変更点：ツールバーにお知らせボタンを追加
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: NotificationView()) {
                        Image(systemName: "bell") // ベルのアイコン
                            .foregroundColor(.primary)
                    }
                }
            }
            
            // ... (以下アラートのコードは変更なし) ...
            .alert("ブロックしますか？", isPresented: $showBlockAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("ブロックする", role: .destructive) {
                    if let target = menuTargetPost {
                        viewModel.blockUser(userID: target.photographerID)
                    }
                }
            } message: {
                Text("このユーザーの投稿が表示されなくなります。")
            }
            
            .alert("通報の理由", isPresented: $showReportAlert) {
                Button("不快なコンテンツ", role: .destructive) {
                    if let target = menuTargetPost { viewModel.reportPost(post: target, reason: "inappropriate") }
                }
                Button("スパム・宣伝", role: .destructive) {
                    if let target = menuTargetPost { viewModel.reportPost(post: target, reason: "spam") }
                }
                Button("その他", role: .destructive) {
                    if let target = menuTargetPost { viewModel.reportPost(post: target, reason: "other") }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("問題の内容を選択してください。")
            }
        }
    }
}
// MARK: - Post Row View (修正版)
struct FeedPostRow: View {
    let post: Post
    @ObservedObject var viewModel: FeedViewModel
    
    // 🆕 親から渡されたアクションを実行するための関数
    var onReport: () -> Void
    var onBlock: () -> Void
    
    @State private var showHeartAnimation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. ヘッダー
            HStack {
                NavigationLink(destination: UserProfileView(
                    targetUserID: post.photographerID,
                    targetUsername: viewModel.usernames[post.photographerID] ?? "ユーザー"
                )) {
                    HStack {
                        if let imageUrl = viewModel.userImages[post.photographerID], !imageUrl.isEmpty {
                            KFImage(URL(string: imageUrl))
                                .resizable().scaledToFill()
                                .frame(width: 40, height: 40).clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable().frame(width: 40, height: 40).foregroundColor(.gray)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.usernames[post.photographerID] ?? "読み込み中")
                                .font(.subheadline).bold()
                                .foregroundColor(.primary)
                            
                            Text(post.dateString)
                                .font(.caption2).foregroundColor(.gray)
                        }
                    }
                }
                .onAppear { viewModel.fetchUserInfo(for: post.photographerID) }
                
                Spacer()
                
                // 🆕 変更点: Menuを使用
                // ボタンの近くにポップアップが出るようになります
                if post.photographerID != Auth.auth().currentUser?.uid {
                    Menu {
                        Button(role: .destructive) {
                            onReport() // 親のアラートを呼び出す
                        } label: {
                            Label("この投稿を通報する", systemImage: "exclamationmark.bubble")
                        }
                        
                        Button(role: .destructive) {
                            onBlock() // 親のアラートを呼び出す
                        } label: {
                            Label("このユーザーをブロックする", systemImage: "hand.raised")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.gray)
                        // 🆕 押しやすくするための修正
                            .frame(width: 44, height: 44) // 大きさを確保
                            .contentShape(Rectangle()) // 透明部分もタップ判定に
                    }
                    // リスト内での動作を安定させる
                    .buttonStyle(BorderlessButtonStyle())
                }
                // 自分の投稿の場合
                else {
                    Menu {
                        Button(role: .destructive) {
                            viewModel.deletePost(post: post)
                        } label: {
                            Label("削除する", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.gray)
                            .frame(width: 44, height: 44) // ここも大きく
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
            .padding(12)
            
            // 2. 写真エリア
            ZStack {
                KFImage(URL(string: post.imageUrl))
                    .resizable().scaledToFill()
                    .frame(maxWidth: .infinity).frame(height: 300)
                    .clipped().background(Color.gray.opacity(0.1))
                    .onTapGesture(count: 2) { handleDoubleTapLike() }
                
                if showHeartAnimation {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                        .shadow(radius: 10)
                        .opacity(0.9)
                        .scaleEffect(1.2)
                        .transition(.scale)
                }
            }
            
            // 3. アクション & ひとこと
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 16) {
                    Button(action: { viewModel.toggleLike(post: post) }) {
                        HStack(spacing: 4) {
                            Image(systemName: viewModel.likedPostIds.contains(post.id ?? "") ? "heart.fill" : "heart")
                                .foregroundColor(viewModel.likedPostIds.contains(post.id ?? "") ? .pink : .primary)
                                .font(.title3)
                            if post.likesCount > 0 {
                                Text("\(post.likesCount)").font(.caption).foregroundColor(.primary)
                            }
                        }
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    
                    NavigationLink(destination: CommentView(postID: post.id ?? "")) {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.right")
                                .foregroundColor(.primary).font(.title3)
                            if let count = post.commentsCount, count > 0 {
                                Text("\(count)").font(.caption).foregroundColor(.primary)
                            }
                        }
                    }
                }
                
                if !post.subjectName.isEmpty {
                    Text(post.subjectName).font(.body)
                        .foregroundColor(.primary)
                        .padding(.top, 4)
                }
            }
            .padding(12)
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
    }
    
    func handleDoubleTapLike() {
        if !viewModel.likedPostIds.contains(post.id ?? "") { viewModel.toggleLike(post: post) }
        withAnimation(.spring()) { showHeartAnimation = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { withAnimation { showHeartAnimation = false } }
    }
}
