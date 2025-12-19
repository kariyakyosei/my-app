import Foundation
import FirebaseFirestore
import FirebaseAuth

// 🆕 通知の名前を定義
extension Notification.Name {
    static let blockListDidUpdate = Notification.Name("blockListDidUpdate")
}

class BlockService {
    static let shared = BlockService()
    private let db = Firestore.firestore()
    
    // 1. ブロックする
    func blockUser(targetUserID: String, completion: @escaping (Error?) -> Void) {
        guard let myUid = Auth.auth().currentUser?.uid else { return }
        let docId = "\(myUid)_\(targetUserID)"
        let data: [String: Any] = [
            "blockerID": myUid,
            "blockedID": targetUserID,
            "timestamp": Timestamp(date: Date())
        ]
        db.collection("blocks").document(docId).setData(data) { error in
            completion(error)
            if error == nil {
                // 🆕 変更通知を送る
                NotificationCenter.default.post(name: .blockListDidUpdate, object: nil)
            }
        }
    }
    
    // 2. ブロックリスト取得
    func fetchBlockedUsers(completion: @escaping ([String]) -> Void) {
        guard let myUid = Auth.auth().currentUser?.uid else {
            completion([])
            return
        }
        db.collection("blocks").whereField("blockerID", isEqualTo: myUid).getDocuments { snapshot, error in
            let blockedIds = snapshot?.documents.compactMap { $0["blockedID"] as? String } ?? []
            completion(blockedIds)
        }
    }
    
    // 3. ブロック解除
    func unblockUser(targetUserID: String, completion: @escaping (Error?) -> Void) {
        guard let myUid = Auth.auth().currentUser?.uid else { return }
        let docId = "\(myUid)_\(targetUserID)"
        
        db.collection("blocks").document(docId).delete { error in
            completion(error)
            if error == nil {
                // 🆕 変更通知を送る
                NotificationCenter.default.post(name: .blockListDidUpdate, object: nil)
            }
        }
    }
    
    // 4. 通報
    func reportPost(postID: String, targetUserID: String, reason: String, completion: @escaping (Error?) -> Void) {
        guard let myUid = Auth.auth().currentUser?.uid else { return }
        let data: [String: Any] = [
            "reporterID": myUid,
            "targetPostID": postID,
            "targetUserID": targetUserID,
            "reason": reason,
            "timestamp": Timestamp(date: Date())
        ]
        db.collection("reports").addDocument(data: data, completion: completion)
    }
}
