import SwiftUI

struct ImageCropper: View {
    let image: UIImage
    var onCrop: (UIImage) -> Void
    var onCancel: () -> Void
    
    // 画像の操作状態
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    // 正方形の枠のサイズ
    private let cropSize: CGFloat = UIScreen.main.bounds.width - 40
    
    var body: some View {
        // NavigationViewは削除し、ZStackとVStackで画面を作ります
        ZStack {
            // 背景（常に黒）
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack {
                // --- 1. カスタムヘッダー ---
                HStack {
                    Button("キャンセル") {
                        onCancel()
                    }
                    .foregroundColor(.white)
                    .padding()
                    
                    Spacer()
                    
                    Text("編集")
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button("完了") {
                        cropTheImage() // 新しい切り抜き処理
                    }
                    .foregroundColor(.yellow)
                    .fontWeight(.bold)
                    .padding()
                }
                .background(Color.black.opacity(0.5)) // ヘッダーの背景
                
                Spacer()
                
                // --- 2. トリミングエリア ---
                ZStack {
                    // 背景（黒）
                    Color.black
                        .frame(width: cropSize, height: cropSize)
                    
                    // 画像
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cropSize, height: cropSize)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScale
                                        lastScale = value
                                        scale = max(scale * delta, 1.0)
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                        withAnimation { correctOffset() }
                                    },
                                DragGesture()
                                    .onChanged { value in
                                        let newOffset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                        offset = limitDrag(newOffset: newOffset)
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                        withAnimation { correctOffset() }
                                    }
                            )
                        )
                        .clipped() // 表示上の切り抜き
                        .overlay(
                            Rectangle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                }
                .frame(width: cropSize, height: cropSize)
                
                Text("ピンチで拡大・ドラッグで位置調整")
                    .foregroundColor(.white)
                    .font(.footnote)
                    .padding()
                
                Spacer()
            }
        }
        // .preferredColorScheme(.dark) は削除しました
    }
    
    // 枠外にはみ出さないための制限計算
    func limitDrag(newOffset: CGSize) -> CGSize {
        let imageRatio = image.size.width / image.size.height
        let viewW: CGFloat
        let viewH: CGFloat
        
        if imageRatio > 1 {
            viewH = cropSize
            viewW = cropSize * imageRatio
        } else {
            viewW = cropSize
            viewH = cropSize / imageRatio
        }
        
        let currentW = viewW * scale
        let currentH = viewH * scale
        
        let maxOffsetX = (currentW - cropSize) / 2
        let maxOffsetY = (currentH - cropSize) / 2
        
        let validX = max(0, maxOffsetX)
        let validY = max(0, maxOffsetY)
        
        var limitedX = newOffset.width
        var limitedY = newOffset.height
        
        if limitedX > validX { limitedX = validX }
        if limitedX < -validX { limitedX = -validX }
        
        if limitedY > validY { limitedY = validY }
        if limitedY < -validY { limitedY = -validY }
        
        return CGSize(width: limitedX, height: limitedY)
    }
    
    func correctOffset() {
        offset = limitDrag(newOffset: offset)
    }
    
    // 🆕 CoreGraphicsを使った確実な切り抜き処理
    func cropTheImage() {
        // 1. 画像が画面上でどういうサイズで描画されているか計算
        let imageRatio = image.size.width / image.size.height
        let fitW: CGFloat
        let fitH: CGFloat
        
        if imageRatio > 1 {
            fitH = cropSize
            fitW = cropSize * imageRatio
        } else {
            fitW = cropSize
            fitH = cropSize / imageRatio
        }
        
        let drawnW = fitW * scale
        let drawnH = fitH * scale
        
        // 2. 切り抜く枠（cropSize）が、画像のどこにあるかを計算
        // (中心基準のoffsetから、左上基準の座標へ変換)
        
        // 画像の左上が、枠の中心からどれだけズレているか
        // ImageCenter = ViewCenter + offset
        // ImageTopLeft = ImageCenter - (drawnSize / 2)
        // CropTopLeft = ViewCenter - (cropSize / 2)
        
        // 求めたいのは、ImageTopLeft から見た CropTopLeft の位置
        // X = CropTopLeft.x - ImageTopLeft.x
        //   = (ViewCenter.x - cropSize/2) - (ViewCenter.x + offset.x - drawnW/2)
        //   = drawnW/2 - cropSize/2 - offset.x
        
        let cropX_inView = (drawnW - cropSize) / 2 - offset.width
        let cropY_inView = (drawnH - cropSize) / 2 - offset.height
        
        // 3. 元画像の座標系に変換
        let factor = image.size.width / drawnW
        let finalX = cropX_inView * factor
        let finalY = cropY_inView * factor
        let finalW = cropSize * factor
        let finalH = cropSize * factor
        
        let cropRect = CGRect(x: finalX, y: finalY, width: finalW, height: finalH)
        
        // 4. CGImageで切り抜き
        if let cgImage = image.cgImage?.cropping(to: cropRect) {
            let croppedUIImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
            onCrop(croppedUIImage)
        } else {
            // 万が一失敗しても、元の画像を返して進行させる
            print("切り抜き失敗：元画像を使用します")
            onCrop(image)
        }
    }
}
