// This file was generated from JSON Schema using quicktype, do not modify it directly.
// To parse the JSON, add this file to your project and do:
//
//   let welcome = try? JSONDecoder().decode(Welcome.self, from: jsonData)

import Foundation
import Foundation


struct LLMResponse: Codable {
    let id, systemFingerprint, object, model: String
    let created: Int
    let choices: [ChoiceRespose]
    let usage: Usage
    
    enum CodingKeys: String, CodingKey {
        case id
        case systemFingerprint = "system_fingerprint"
        case object, model, created, choices, usage
    }
}

// MARK: - Choice
struct ChoiceRespose: Codable {
    let index: Int
    let finish_reason: String
    let message: Message
}

// MARK: - Message
struct Message: Codable {
    let role, content: String
}

// MARK: - Usage
struct Usage: Codable {
    let promptTokens, completionTokens, totalTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}
