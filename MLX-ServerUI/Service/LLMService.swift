//
//  LLMService.swift
//  MLX-ServerUI
//
//  Created by Muhammad Tafani Rabbani on 27/08/24.
//

import Foundation
import Combine
protocol LLMService{
    func fetchResponse(args: [String:Any],port:String) -> AnyPublisher<LLMResponse, any Error>
    func streamResponse(args: [String:Any],port:String) -> AnyPublisher<LLMStream, any Error> 
}
