import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SignUpView: View {
    @AppStorage("isAuthenticated") var isAuthenticated: Bool = false
    
    // モード切り替え (true: ログイン, false: 新規登録)
    @State private var isLoginMode = true
    
    @State private var email = ""
    @State private var password = ""
    @State private var username = "" // 新規登録の時だけ使う
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 24) {
            
            // 1. タイトル
            Text(isLoginMode ? "ログイン" : "アカウント作成")
                .font(.system(size: 32, weight: .bold))
                .padding(.bottom, 20)
            
            // 2. 入力フォーム
            VStack(spacing: 16) {
                // ユーザー名は「新規登録」の時だけ表示
                if !isLoginMode {
                    TextField("表示名 (例: あかね)", text: $username)
                        .textFieldStyle(AuthTextFieldStyle())
                        .textInputAutocapitalization(.never)
                }
                
                TextField("メールアドレス", text: $email)
                    .textFieldStyle(AuthTextFieldStyle())
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                
                SecureField("パスワード (6文字以上)", text: $password)
                    .textFieldStyle(AuthTextFieldStyle())
            }
            
            // エラーメッセージ
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            
            // 3. メインボタン (ログイン / 登録)
            Button(action: {
                handleAction()
            }) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(isLoginMode ? "ログイン" : "登録して始める")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .background(isValid() ? Color.accentColor : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled(!isValid() || isLoading)
            
            // 4. 切り替えボタン
            Button(action: {
                withAnimation {
                    isLoginMode.toggle()
                    errorMessage = "" // エラー消去
                }
            }) {
                Text(isLoginMode ? "アカウントをお持ちでない方はこちら" : "すでにアカウントをお持ちの方はこちら")
                    .font(.footnote)
                    .foregroundColor(.blue)
            }
            
        }
        .padding(30)
    }
    
    // 入力チェック
    func isValid() -> Bool {
        if isLoginMode {
            return !email.isEmpty && !password.isEmpty
        } else {
            return !email.isEmpty && !password.isEmpty && !username.isEmpty
        }
    }
    
    // ボタンが押された時の処理
    func handleAction() {
        isLoading = true
        errorMessage = ""
        
        if isLoginMode {
            login()
        } else {
            register()
        }
    }
    
    // --- ログイン処理 ---
    func login() {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            isLoading = false
            if let error = error {
                self.errorMessage = "ログイン失敗: メールアドレスかパスワードが間違っています。"
                print("Error: \(error.localizedDescription)")
            } else {
                print("ログイン成功")
                self.isAuthenticated = true // 画面遷移
            }
        }
    }
    
    // --- 新規登録処理 ---
    func register() {
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                self.isLoading = false
                self.errorMessage = "登録エラー: \(error.localizedDescription)"
            } else {
                if let uid = result?.user.uid {
                    saveUserProfile(uid: uid)
                }
            }
        }
    }
    
    // プロフィール保存
    func saveUserProfile(uid: String) {
        let db = Firestore.firestore()
        let userData: [String: Any] = [
            "uid": uid,
            "username": username,
            "email": email,
            "createdAt": Timestamp(date: Date())
        ]
        
        db.collection("users").document(uid).setData(userData) { error in
            self.isLoading = false
            if let error = error {
                self.errorMessage = "プロフィールの保存に失敗しました。"
            } else {
                self.isAuthenticated = true // 画面遷移
            }
        }
    }
}

// デザイン用のカスタムスタイル
struct AuthTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
    }
}
