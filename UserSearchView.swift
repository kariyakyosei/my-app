import SwiftUI
import FirebaseFirestore
import Kingfisher

struct UserSearchView: View {
    @State private var searchText = ""
    @State private var searchResults: [User] = [] // 検索結果のユーザーリスト
    
    var body: some View {
        VStack {
            // 検索バー
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("ユーザー名で検索...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .onChange(of: searchText) { newValue in
                        searchUsers(query: newValue)
                    }
            }
            .padding()
            
            // 結果リスト
            if searchResults.isEmpty {
                Spacer()
                Text(searchText.isEmpty ? "ユーザーを検索してみよう" : "見つかりませんでした")
                    .foregroundColor(.gray)
                Spacer()
            } else {
                List(searchResults) { user in
                    NavigationLink(destination: UserProfileView(
                        targetUserID: user.uid,
                        targetUsername: user.username
                    )) {
                        HStack {
                            // アイコン
                            if let url = user.profileImageUrl, !url.isEmpty {
                                KFImage(URL(string: url))
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.gray)
                            }
                            
                            Text(user.username)
                                .font(.headline)
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle("検索")
    }
    
    // 検索処理
    func searchUsers(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        let db = Firestore.firestore()
        // 前方一致検索のテクニック（入力した文字〜その文字の終わりまで）
        db.collection("users")
            .whereField("username", isGreaterThanOrEqualTo: query)
            .whereField("username", isLessThan: query + "\u{f8ff}")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("検索エラー: \(error)")
                    return
                }
                
                self.searchResults = snapshot?.documents.compactMap { document in
                    try? document.data(as: User.self)
                } ?? []
            }
    }
}

// ユーザーデータの設計図（検索用）
struct User: Identifiable, Codable {
    @DocumentID var id: String?
    var uid: String
    var username: String
    var profileImageUrl: String?
}
