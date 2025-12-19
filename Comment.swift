import Foundation
import FirebaseFirestore

struct Comment: Identifiable, Codable {
    @DocumentID var id: String?
    var postID: String      // どの投稿へのコメントか
    var userID: String      // 誰が書いたか
    var username: String    // 書いた人の名前
    var userIconUrl: String // 🆕 アイコン画像のURLを追加！
    var text: String        // コメント内容
    var createdAt: Date     // 日付
}
