//
//  NetWorkSevice.swift
//  poseLiveStream
//
//  Created by Евгений on 17.07.2025.
//

import UIKit
import Foundation

class NetworkService {
    private let baseURL = "https://your-server.com/api/" 
    private let session = URLSession.shared
    
    func classifyPose(image: UIImage, completion: @escaping (Result<PoseClassificationResult, Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
            completion(.failure(NSError(domain: "ImageError", code: 0, userInfo: nil)))
            return
        }
        
        let url = URL(string: "\(baseURL)classify-pose")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "NoData", code: 0, userInfo: nil)))
                return
            }
            
            do {
                let result = try JSONDecoder().decode(PoseClassificationResult.self, from: data)
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
