import SwiftUI
import FirebaseAuth
import Kingfisher

struct ProfileView: View {
    @AppStorage("isAuthenticated") var isAuthenticated: Bool = true
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showEditProfile = false
    
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // --- ヘッダーエリア ---
                    HStack(spacing: 20) {
                        if !viewModel.profileImageUrl.isEmpty {
                            KFImage(URL(string: viewModel.profileImageUrl))
                                .resizable().scaledToFill()
                                .frame(width: 80, height: 80).clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable().frame(width: 80, height: 80).foregroundColor(.gray)
                        }
                        
                        HStack(spacing: 30) {
                            VStack {
                                Text("\(viewModel.myPosts.count)").font(.title2).bold()
                                Text("投稿").font(.caption).foregroundColor(.gray)
                            }
                            VStack {
                                Text("\(viewModel.friendsCount)").font(.title2).bold()
                                Text("フレンド").font(.caption).foregroundColor(.gray)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal).padding(.top, 10)
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text(viewModel.username).font(.title3).bold()
                        if !viewModel.bio.isEmpty { Text(viewModel.bio).font(.body) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
                    
                    // --- ボタンエリア（編集ボタンだけ残す） ---
                    Button(action: { showEditProfile = true }) {
                        Text("プロフィールを編集")
                            .font(.subheadline).fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.1))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    
                    // 🗑️ ログアウト・退会ボタンは削除しました（設定画面へ移動）
                    
                    Divider().padding(.vertical, 5)
                    
                    // --- 投稿ギャラリー ---
                    if viewModel.myPosts.isEmpty {
                        Text("まだ投稿がありません").foregroundColor(.gray).padding(.top, 50)
                    } else {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(viewModel.myPosts) { post in
                                KFImage(URL(string: post.imageUrl))
                                    .resizable().scaledToFill()
                                    .frame(width: UIScreen.main.bounds.width / 3 - 2, height: UIScreen.main.bounds.width / 3 - 2)
                                    .clipped()
                            }
                        }
                    }
                }
            }
            .navigationTitle(viewModel.username)
            .navigationBarTitleDisplayMode(.inline)
            
            .onAppear { viewModel.loadAllData() }
            .sheet(isPresented: $showEditProfile) {
                ProfileEditView(viewModel: viewModel)
            }
        }
    }
}
