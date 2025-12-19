import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore
import Kingfisher

// ViewModel (変更なし)
class SettingsViewModel: ObservableObject {
    @Published var blockedUsers: [User] = []
    
    func fetchBlockedList() {
        BlockService.shared.fetchBlockedUsers { [weak self] ids in
            guard !ids.isEmpty else {
                DispatchQueue.main.async { self?.blockedUsers = [] }
                return
            }
            let db = Firestore.firestore()
            var users: [User] = []
            let group = DispatchGroup()
            
            for id in ids {
                group.enter()
                db.collection("users").document(id).getDocument { snapshot, _ in
                    if let user = try? snapshot?.data(as: User.self) {
                        users.append(user)
                    }
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                self?.blockedUsers = users
            }
        }
    }
    
    func unblock(user: User) {
        BlockService.shared.unblockUser(targetUserID: user.uid) { [weak self] error in
            if error == nil {
                DispatchQueue.main.async {
                    self?.blockedUsers.removeAll { $0.uid == user.uid }
                }
            }
        }
    }
    
    func deleteAccount(completion: @escaping (Error?) -> Void) {
        guard let user = Auth.auth().currentUser else { return }
        let uid = user.uid
        let db = Firestore.firestore()
        db.collection("users").document(uid).delete { error in
            if let error = error { completion(error); return }
            user.delete { error in completion(error) }
        }
    }
}

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @AppStorage("isAuthenticated") var isAuthenticated: Bool = true
    
    @State private var showLogoutAlert = false
    @State private var showDeleteAlert = false
    
    var body: some View {
        // 🆕 ここ変更点！ タブになるのでNavigationStackで包みます
        NavigationStack {
            List {
                Section(header: Text("プライバシー")) {
                    NavigationLink(destination: BlockedUsersListView(viewModel: viewModel)) {
                        HStack {
                            Text("ブロックしたユーザー")
                            Spacer()
                            Text("\(viewModel.blockedUsers.count)人")
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Section(header: Text("アカウント")) {
                    Button(action: { showLogoutAlert = true }) {
                        Text("ログアウト")
                            .foregroundColor(.primary)
                    }
                    
                    Button(action: { showDeleteAlert = true }) {
                        Text("アカウント削除（退会）")
                            .foregroundColor(.red)
                    }
                }
                
                Section(header: Text("アプリ情報")) {
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("設定") // タイトル設定
            .onAppear {
                viewModel.fetchBlockedList()
            }
            .alert("ログアウトしますか？", isPresented: $showLogoutAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("ログアウト", role: .destructive) {
                    try? Auth.auth().signOut()
                    isAuthenticated = false
                }
            }
            .alert("本当に退会しますか？", isPresented: $showDeleteAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("退会する", role: .destructive) {
                    viewModel.deleteAccount { error in
                        if error == nil {
                            isAuthenticated = false
                        }
                    }
                }
            } message: {
                Text("この操作は取り消せません。")
            }
        }
    }
}

// BlockedUsersListView は変更なし（そのまま使います）
struct BlockedUsersListView: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        List {
            if viewModel.blockedUsers.isEmpty {
                Text("ブロックしているユーザーはいません")
                    .foregroundColor(.gray)
            } else {
                ForEach(viewModel.blockedUsers) { user in
                    HStack {
                        if let url = user.profileImageUrl, !url.isEmpty {
                            KFImage(URL(string: url))
                                .resizable().scaledToFill().frame(width: 40, height: 40).clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable().frame(width: 40, height: 40).foregroundColor(.gray)
                        }
                        
                        Text(user.username)
                            .font(.headline)
                        
                        Spacer()
                        
                        Button("解除") {
                            viewModel.unblock(user: user)
                        }
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(16)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("ブロックしたユーザー")
    }
}
