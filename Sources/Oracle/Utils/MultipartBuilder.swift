import Foundation

struct MultipartBuilder {
    private let boundary: String
    private var body = Data()
    
    init(boundary: String = UUID().uuidString) {
        self.boundary = boundary
    }
    
    var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }
    
    mutating func addField(name: String, value: String) {
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(value)\r\n".data(using: .utf8)!)
    }
    
    mutating func addFile(name: String, filename: String, mimeType: String, data: Data) {
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
    }
    
    func build() -> Data {
        var final = body
        final.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return final
    }
}
