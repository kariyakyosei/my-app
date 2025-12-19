import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

class CommentViewModel: ObservableObject {
    @Published var comments: [Comment] = []
    
    // コメントを読み込む
    func fetchComments(postID: String) {
        let db = Firestore.firestore()
        
        // ※もしインデックスエラーが出たらコンソールのリンクから作成してください
        db.collection("comments")
            .whereField("postID", isEqualTo: postID)
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                self.comments = snapshot?.documents.compactMap { document in
                    try? document.data(as: Comment.self)
                } ?? []
            }
    }
    
    // コメントを書き込む
    func addComment(postID: String, text: String) {
        guard let uid = Auth.auth().currentUser?.uid, !text.isEmpty else { return }
        let db = Firestore.firestore()
        
        // 1. 自分の情報を取得
        db.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error { print("ユーザー取得エラー: \(error)"); return }
            guard let data = snapshot?.data() else { return }
            
            let username = data["username"] as? String ?? "名無し"
            let userIcon = data["profileImageUrl"] as? String ?? ""
            
            // 2. コメントを作成（アイコンURLも含める！）
            let newComment = Comment(
                postID: postID,
                userID: uid,
                username: username,
                userIconUrl: userIcon, // 🆕 ここに追加
                text: text,
                createdAt: Date()
            )
            
            do {
                // 保存
                try db.collection("comments").addDocument(from: newComment)
                
                // 投稿のコメント数を +1
                let postRef = db.collection("posts").document(postID)
                postRef.updateData(["commentsCount": FieldValue.increment(Int64(1))])
                
                // 投稿主に通知を送る（自分以外なら）
                postRef.getDocument { postSnapshot, _ in
                    if let postData = postSnapshot?.data(),
                       let ownerID = postData["photographerID"] as? String,
                       let postImageUrl = postData["imageUrl"] as? String,
                       ownerID != uid {
                        
                        let notificationData: [String: Any] = [
                            "type": "comment",
                            "receiverID": ownerID,
                            "senderID": uid,
                            "senderUsername": username,
                            "senderIconUrl": userIcon,
                            "postID": postID,
                            "postImageUrl": postImageUrl,
                            "message": text,
                            "createdAt": Timestamp(date: Date())
                        ]
                        db.collection("notifications").addDocument(data: notificationData)
                    }
                }
            } catch {
                print("コメント保存エラー: \(error)")
            }
        }
    }
    
    // 🆕 コメント削除機能
    func deleteComment(comment: Comment) {
        guard let commentID = comment.id else { return }
        
        let db = Firestore.firestore()
        
        // 1. コメントを削除
        db.collection("comments").document(commentID).delete { error in
            if let error = error {
                print("削除エラー: \(error)")
            } else {
                print("コメント削除成功")
                // 2. 投稿のコメント数を -1 する
                db.collection("posts").document(comment.postID).updateData([
                    "commentsCount": FieldValue.increment(Int64(-1))
                ])
            }
        }
    }
}
