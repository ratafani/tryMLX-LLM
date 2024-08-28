//
//  NetworkRoute.swift
//  MLX-ServerUI
//
//  Created by Muhammad Tafani Rabbani on 27/08/24.
//

import Foundation

// MARK: - NetworkRoutes
enum NetworkRoutes {
    case llm(port:String)
}

extension NetworkRoutes: RouteService {
    
    var scheme: String {
        "http"
    }
    
    var host: String {
        switch self {
        case .llm(let port):
            return "localhost"
        }
    }
    var port: String {
        switch self {
        case .llm(let port):
            return port
        }
    }
    var path: String {
        switch self {
        case .llm:
            return "/v1/chat/completions"
        }
    }
    
}

extension NetworkRoutes {
    func asURLRequest(args :[String:Any]) -> URLRequest? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = path
        components.port = 8080
//        components.queryItems = pageQuery(parameter: args)
        
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        print(url,"The URL")
        // Convert the dictionary to JSON data
        guard let httpBody = try? JSONSerialization.data(withJSONObject: args, options: []) else {
            print("Error in JSON serialization")
            return nil
        }
        
        request.httpMethod = "POST"
        // Set the content type to JSON
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//        request.setValue("text/event-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody
       

        return request
    }
}
