import SwiftUI
import FirebaseAuth
import Kingfisher

struct CommentView: View {
    let postID: String
    @StateObject private var viewModel = CommentViewModel()
    @State private var newCommentText = ""
    
    // 自分のID
    private let myUid = Auth.auth().currentUser?.uid
    
    var body: some View {
        VStack {
            // コメント一覧エリア
            if viewModel.comments.isEmpty {
                Spacer()
                Text("まだコメントはありません")
                    .foregroundColor(.gray)
                Spacer()
            } else {
                List(viewModel.comments) { comment in
                    HStack(alignment: .top, spacing: 12) {
                        
                        // アイコン表示
                        if !comment.userIconUrl.isEmpty {
                            KFImage(URL(string: comment.userIconUrl))
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
                        
                        // 名前と本文
                        VStack(alignment: .leading, spacing: 4) {
                            Text(comment.username)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                            
                            Text(comment.text)
                                .font(.body)
                                .foregroundColor(.primary) // 🌙 自動切り替え
                        }
                    }
                    .padding(.vertical, 4)
                    // リストの行背景を透明にして、親の背景色を適用させる
                    .listRowBackground(Color(UIColor.systemBackground))
                    .contextMenu {
                        if comment.userID == myUid {
                            Button(role: .destructive) {
                                viewModel.deleteComment(comment: comment)
                            } label: {
                                Label("削除する", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
                // 🌙 リスト全体の背景
                .background(Color(UIColor.systemBackground))
            }
            
            Divider()
            
            // 入力エリア
            HStack {
                TextField("コメントを入力...", text: $newCommentText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                // 🌙 テキストフィールドの文字色も念のため指定
                    .foregroundColor(.primary)
                
                Button(action: {
                    sendComment()
                }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white) // ボタン内のアイコンは白のまま
                        .padding(8)
                        .background(newCommentText.isEmpty ? Color.gray : Color.accentColor) // テーマカラー使用
                        .clipShape(Circle())
                }
                .disabled(newCommentText.isEmpty)
            }
            .padding()
            // 🌙 入力エリアの背景
            .background(Color(UIColor.systemBackground))
        }
        .navigationTitle("コメント")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(UIColor.systemBackground)) // 🌙 画面全体の背景
        .onAppear {
            viewModel.fetchComments(postID: postID)
        }
    }
    
    func sendComment() {
        viewModel.addComment(postID: postID, text: newCommentText)
        newCommentText = ""
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
