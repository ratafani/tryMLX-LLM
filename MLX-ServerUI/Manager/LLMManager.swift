//
//  LLMManager.swift
//  MLX-ServerUI
//
//  Created by Muhammad Tafani Rabbani on 27/08/24.
//

import Foundation
import Combine

class LLMManager:LLMService{
    
    private let networkService: NetworkService
    
    init(networkService: NetworkService) {
        self.networkService = networkService
    }
    func fetchResponse(args: [String:Any],port:String) -> AnyPublisher<LLMResponse, any Error> {
        print("try to fetch")
        return networkService.request(router: .llm(port: port), args: args)
    }
    
    func streamResponse(args: [String:Any],port:String) -> AnyPublisher<LLMStream, any Error> {
        print("try to stream")
        return networkService.streamResponse(router: .llm(port: port), args: args)
    }
    
    
}
