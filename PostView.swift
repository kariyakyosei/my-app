import SwiftUI
import PhotosUI
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth

struct PostView: View {
    @Binding var selectedTab: Int
    @Binding var showFriendsOnly: Bool
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var originalImage: UIImage? = nil
    @State private var selectedImage: UIImage? = nil
    
    @State private var showCropper = false
    @State private var subjectName = ""
    
    @State private var isUploading = false
    @State private var showingSuccessAlert = false
    
    var body: some View {
        // 🆕 変更点1：ZStackで画面全体を包む
        ZStack {
            
            // --- 元の投稿画面 ---
            NavigationStack {
                VStack(spacing: 20) {
                    // 1. 写真選択ボタンエリア
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 300, height: 300)
                            .cornerRadius(10)
                            .onTapGesture {
                                selectedItem = nil
                                originalImage = nil
                                selectedImage = nil
                            }
                    } else {
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            ZStack {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 300, height: 300)
                                    .cornerRadius(10)
                                
                                VStack {
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                    Text("タップして写真を選択")
                                    Text("(正方形に切り取ります)")
                                        .font(.caption)
                                }
                                .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    // 2. テキスト入力エリア
                    TextField("ひとこと (なくてもOK)", text: $subjectName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    
                    Spacer()
                    
                    // 3. 投稿ボタン
                    Button(action: {
                        uploadPost()
                    }) {
                        if isUploading {
                            ProgressView()
                        } else {
                            Text("投稿する")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(selectedImage == nil ? Color.gray : Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .disabled(selectedImage == nil || isUploading)
                    .padding()
                }
                .navigationTitle("新規投稿")
                .navigationBarTitleDisplayMode(.inline)
            }
            .zIndex(0) // 下のレイヤー
            
            // --- 🆕 変更点2：トリミング画面を「重ねて」表示する ---
            // fullScreenCoverを使わず、条件分岐で表示します
            if showCropper, let imageToCrop = originalImage {
                ImageCropper(image: imageToCrop, onCrop: { croppedImage in
                    // 切り抜き完了
                    self.selectedImage = croppedImage
                    self.originalImage = nil
                    self.selectedItem = nil
                    self.showCropper = false
                }, onCancel: {
                    // キャンセル
                    self.originalImage = nil
                    self.selectedItem = nil
                    self.showCropper = false
                })
                .zIndex(1) // 上のレイヤー
                .transition(.opacity) // ふわっと表示
            }
        }
        // --- 変更点3：画像読み込み処理 ---
        .onChange(of: selectedItem) { newItem in
            guard let newItem = newItem else { return }
            Task {
                // 読み込み
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    
                    // リサイズ処理 (軽量化)
                    let resizedImage = resizeImage(image: uiImage, targetSize: CGSize(width: 1080, height: 1080))
                    
                    await MainActor.run {
                        self.originalImage = resizedImage
                        self.showCropper = true // ここで重ね合わせ画面を表示！
                    }
                }
            }
        }
        .alert("投稿完了", isPresented: $showingSuccessAlert) {
            Button("OK") {
                resetForm()
                showFriendsOnly = false
                selectedTab = 0
            }
        } message: {
            Text("フィードに投稿しました！")
        }
    }
    
    // 画像リサイズ関数
    func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
        }
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage ?? image
    }
    
    // 投稿処理
    func uploadPost() {
        guard let image = selectedImage, let uid = Auth.auth().currentUser?.uid else { return }
        isUploading = true
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            isUploading = false
            return
        }
        
        let filename = UUID().uuidString
        let storageRef = Storage.storage().reference().child("post_images/\(filename).jpg")
        
        storageRef.putData(imageData, metadata: nil) { _, error in
            if let error = error {
                print("画像アップロード失敗: \(error)")
                isUploading = false
                return
            }
            
            storageRef.downloadURL { url, error in
                guard let imageUrl = url?.absoluteString else {
                    isUploading = false
                    return
                }
                
                let db = Firestore.firestore()
                db.collection("users").document(uid).getDocument { snapshot, _ in
                    let username = snapshot?.data()?["username"] as? String ?? "名無し"
                    
                    let postData: [String: Any] = [
                        "userID": uid,
                        "photographerID": uid,
                        "username": username,
                        "imageUrl": imageUrl,
                        "subjectName": self.subjectName,
                        "createdAt": Timestamp(date: Date()),
                        "likesCount": 0,
                        "commentsCount": 0
                    ]
                    
                    db.collection("posts").addDocument(data: postData) { error in
                        isUploading = false
                        if error == nil {
                            showingSuccessAlert = true
                        }
                    }
                }
            }
        }
    }
    
    func resetForm() {
        selectedItem = nil
        originalImage = nil
        selectedImage = nil
        subjectName = ""
    }
}
