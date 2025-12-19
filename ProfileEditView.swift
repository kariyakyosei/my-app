import SwiftUI
import PhotosUI
import Kingfisher

struct ProfileEditView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) var dismiss // 画面を閉じる用
    
    // 編集用の変数
    @State private var name: String
    @State private var bio: String
    
    // 画像選択用
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var isSaving = false
    
    // 初期化（今のデータを受け取る）
    init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel
        _name = State(initialValue: viewModel.username)
        _bio = State(initialValue: viewModel.bio)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // --- アイコン画像 ---
                Section {
                    HStack {
                        Spacer()
                        VStack {
                            if let image = selectedImage {
                                // 新しく選んだ画像
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else if !viewModel.profileImageUrl.isEmpty {
                                // 今設定されている画像
                                KFImage(URL(string: viewModel.profileImageUrl))
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                // デフォルト画像
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .foregroundColor(.gray)
                                    .frame(width: 100, height: 100)
                            }
                            
                            // 画像変更ボタン
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                Text("写真を変更")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                    .padding(.top, 5)
                            }
                        }
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear) // 背景を透明に
                
                // --- 入力エリア ---
                Section(header: Text("名前")) {
                    TextField("名前を入力", text: $name)
                }
                
                Section(header: Text("自己紹介")) {
                    TextField("自己紹介を入力", text: $bio, axis: .vertical) // 複数行OK
                        .lineLimit(3...5)
                }
            }
            .navigationTitle("プロフィール編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // キャンセルボタン
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                // 保存ボタン
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        saveProfile()
                    }) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("保存")
                                .fontWeight(.bold)
                        }
                    }
                    .disabled(name.isEmpty || isSaving)
                }
            }
            // 画像選択時の処理
            .onChange(of: selectedItem) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        selectedImage = uiImage
                    }
                }
            }
        }
    }
    
    // 保存処理
    func saveProfile() {
        isSaving = true
        // ViewModelにお願いして保存する
        viewModel.updateProfile(newImage: selectedImage, newName: name, newBio: bio) {
            isSaving = false
            dismiss() // 完了したら閉じる
        }
    }
}
