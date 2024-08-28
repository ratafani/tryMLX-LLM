//
//  NetworkService.swift
//  MLX-ServerUI
//
//  Created by Muhammad Tafani Rabbani on 27/08/24.
//

import Foundation
import Combine

protocol NetworkService{
    func request <T:Decodable>(router : NetworkRoutes,args:[String:Any]) -> AnyPublisher<T,Error>
    func streamResponse(router: NetworkRoutes,args:[String:Any]) -> AnyPublisher<LLMStream, Error>
}
