import Foundation
import FirebaseFirestore

struct Post: Identifiable, Codable {
    @DocumentID var id: String?
    var userID: String
    var photographerID: String
    var username: String
    var imageUrl: String
    var subjectName: String
    var createdAt: Date
    var likesCount: Int
    var commentsCount: Int?
    
    // 🆕 賢くなった日付表示ロジック
    var dateString: String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day], from: createdAt, to: now)
        
        if let day = components.day, day > 0 {
            if day == 1 { return "昨日" }
            if day < 7 { return "\(day)日前" }
            // 1週間以上前なら日付を表示
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            return formatter.string(from: createdAt)
        }
        
        if let hour = components.hour, hour > 0 {
            return "\(hour)時間前"
        }
        
        if let minute = components.minute, minute > 0 {
            return "\(minute)分前"
        }
        
        return "たった今"
    }
}
