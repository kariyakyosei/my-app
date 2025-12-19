// ... (前のコードと同じ部分は省略せず、全体を書き換えてください)

import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

class ProfileViewModel: ObservableObject {
    @Published var myPosts: [Post] = []
    @Published var friendsCount: Int = 0
    @Published var username: String = "..."
    @Published var bio: String = ""
    @Published var profileImageUrl: String = ""
    
    func loadAllData() {
        fetchMyPosts()
        fetchProfileData()
    }
    
    func fetchMyPosts() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("posts")
            .whereField("photographerID", isEqualTo: uid)
            .order(by: "createdAt", descending: true)
            .getDocuments { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.myPosts = snapshot?.documents.compactMap { try? $0.data(as: Post.self) } ?? []
                }
            }
    }
    
    func fetchProfileData() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        db.collection("users").document(uid).getDocument { snapshot, _ in
            if let data = snapshot?.data() {
                DispatchQueue.main.async {
                    self.username = data["username"] as? String ?? "名無し"
                    self.bio = data["bio"] as? String ?? ""
                    self.profileImageUrl = data["profileImageUrl"] as? String ?? ""
                }
            }
        }
        
        db.collection("friendships")
            .whereField("followerID", isEqualTo: uid)
            .getDocuments { snapshot, _ in
                DispatchQueue.main.async {
                    self.friendsCount = snapshot?.count ?? 0
                }
            }
    }
    
    func updateProfile(newImage: UIImage?, newName: String, newBio: String, completion: @escaping () -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        var userData: [String: Any] = ["username": newName, "bio": newBio]
        
        if let image = newImage, let imageData = image.jpegData(compressionQuality: 0.5) {
            let storageRef = Storage.storage().reference().child("profile_images/\(uid).jpg")
            storageRef.putData(imageData, metadata: nil) { _, error in
                if error == nil {
                    storageRef.downloadURL { url, _ in
                        if let urlString = url?.absoluteString {
                            userData["profileImageUrl"] = urlString
                            db.collection("users").document(uid).updateData(userData) { _ in
                                self.fetchProfileData()
                                completion()
                            }
                        }
                    }
                }
            }
        } else {
            db.collection("users").document(uid).updateData(userData) { _ in
                self.fetchProfileData()
                completion()
            }
        }
    }
    
    func deletePost(post: Post) {
        guard let postID = post.id else { return }
        let storageRef = Storage.storage().reference(forURL: post.imageUrl)
        storageRef.delete { _ in
            Firestore.firestore().collection("posts").document(postID).delete { error in
                if error == nil {
                    DispatchQueue.main.async {
                        self.myPosts.removeAll { $0.id == postID }
                    }
                }
            }
        }
    }
    
    // 🆕 退会機能
    func deleteAccount(completion: @escaping (Error?) -> Void) {
        guard let user = Auth.auth().currentUser else { return }
        let uid = user.uid
        let db = Firestore.firestore()
        
        // 1. ユーザーデータを削除 (完全な削除は大変なので、まずはプロフィールを消す)
        db.collection("users").document(uid).delete { error in
            if let error = error {
                completion(error)
                return
            }
            
            // 2. 認証アカウントを削除
            user.delete { error in
                completion(error)
            }
        }
    }
}
