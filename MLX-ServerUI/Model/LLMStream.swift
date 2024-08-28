//
//  LLMStream.swift
//  MLX-ServerUI
//
//  Created by Muhammad Tafani Rabbani on 28/08/24.
//


import Foundation

// MARK: - Welcome8
struct LLMStream:Codable {
    let id, systemFingerprint, object, model: String?
    let created: Int
    let choices: [Choice]
}

// MARK: - Choice
struct Choice:Codable {
    let index: Int?
//    let logprobs: Logprobs
    let finishReason: String?
    let delta: Delta
}

// MARK: - Delta
struct Delta:Codable {
    let role, content: String?
}

//// MARK: - Logprobs
//struct Logprobs:Codable {
//    let tokenLogprobs, topLogprobs: [Any?]
//    let tokens: NSNull
//}
