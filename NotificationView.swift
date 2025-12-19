import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth
import Kingfisher

// 通知データモデル
struct NotificationModel: Identifiable, Codable {
    @DocumentID var id: String?
    var type: String
    var receiverID: String
    var senderID: String
    var senderUsername: String
    var senderIconUrl: String
    var postID: String
    var postImageUrl: String
    var message: String
    var createdAt: Date
}

class NotificationViewModel: ObservableObject {
    @Published var notifications: [NotificationModel] = []
    
    func fetchNotifications() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("notifications")
            .whereField("receiverID", isEqualTo: uid)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, _ in
                self?.notifications = snapshot?.documents.compactMap { try? $0.data(as: NotificationModel.self) } ?? []
            }
    }
}

struct NotificationView: View {
    @StateObject private var viewModel = NotificationViewModel()
    
    var body: some View {
        NavigationStack {
            List(viewModel.notifications) { item in
                HStack(spacing: 12) {
                    // アイコン
                    if !item.senderIconUrl.isEmpty {
                        KFImage(URL(string: item.senderIconUrl))
                            .resizable().scaledToFill().frame(width: 44, height: 44).clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable().frame(width: 44, height: 44).foregroundColor(.gray)
                    }
                    
                    // 文章
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.senderUsername)
                            .font(.headline)
                            .foregroundColor(.primary) // 🌙
                        
                        Text(makeMessage(item: item))
                            .font(.subheadline)
                            .foregroundColor(.secondary) // 🌙 少し薄い色
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    // 投稿画像（あれば）
                    if !item.postImageUrl.isEmpty {
                        KFImage(URL(string: item.postImageUrl))
                            .resizable().scaledToFill().frame(width: 44, height: 44).cornerRadius(4)
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(Color(UIColor.systemBackground)) // 🌙
            }
            .listStyle(PlainListStyle())
            .background(Color(UIColor.systemBackground)) // 🌙
            .navigationTitle("お知らせ")
            .onAppear { viewModel.fetchNotifications() }
        }
    }
    
    func makeMessage(item: NotificationModel) -> String {
        switch item.type {
        case "like": return "あなたの投稿にいいねしました"
        case "comment": return "コメントしました: \(item.message)"
        case "friend": return "あなたをフレンドに追加しました"
        default: return "アクションがありました"
        }
    }
}
