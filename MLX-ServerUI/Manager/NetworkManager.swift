//
//  NetworkManager.swift
//  MLX-ServerUI
//
//  Created by Muhammad Tafani Rabbani on 27/08/24.
//

import Foundation
import Combine

struct SSEEvent {
    let data: String
}

class NetworkManager: NetworkService {
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func streamResponse(router: NetworkRoutes,args:[String:Any]) -> AnyPublisher<LLMStream, Error> {
        
        guard let request = router.asURLRequest(args: args) else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        print("try call session")
        
        return session.dataTaskPublisher(for: request)
            .tryMap { output in
                try self.validateResponse(output.response)
                return output.data
            }
            .flatMap { data-> AnyPublisher<LLMStream, Error> in
                var events = String(data: data, encoding: .utf8)?
                    .components(separatedBy: "\n\n")
                    .compactMap { eventString -> Data? in
                        let lines = eventString.components(separatedBy: "\n")
                        let dataLine = lines.first(where: { $0.hasPrefix("data:") })
                        guard let jsonString = dataLine?.dropFirst(5).trimmingCharacters(in: .whitespacesAndNewlines) else {
                            return nil
                        }
                        return jsonString.data(using: .utf8)
                    } ?? []
//                do {
//                    let jsonData = events.first
//                    let welcome3 = try JSONDecoder().decode(LLMStream.self, from: jsonData ?? Data())
//                    print(welcome3)
//                } catch {
//                    print("Error decoding JSON: \(error)")
//                }
                events.removeLast()
                return events.publisher
                    .setFailureType(to: Error.self)
                    .flatMap { eventData -> AnyPublisher<LLMStream, Error> in
                        do {
                            let jsonData = eventData
                            let welcome3 = try JSONDecoder().decode(LLMStream.self, from: jsonData ?? Data())
                            print(welcome3.choices.first?.delta.content)
                        } catch {
                            print("Error decoding JSON: \(error)")
                        }
                        return Just(eventData)
                            .decode(type: LLMStream.self, decoder: JSONDecoder())
                            .eraseToAnyPublisher()
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    func request<T>(router: NetworkRoutes,args:[String:Any]) -> AnyPublisher<T, Error> where T: Decodable {
        guard let request = router.asURLRequest(args: args) else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        print("try call session")
        
        return session.dataTaskPublisher(for: request)
            .tryMap { output in
                try self.validateResponse(output.response)
//                do {
//                    let jsonData = output.data
//                    let welcome3 = try JSONDecoder().decode(LLMResponse.self, from: jsonData)
//                    print(welcome3)
//                } catch {
//                    print("Error decoding JSON: \(error)")
//                }
                return output.data
            }
            .flatMap { data -> AnyPublisher<T, Error> in
                
                return self.decode(data)
            }
            .eraseToAnyPublisher()
    }
    
    private func validateResponse(_ response: URLResponse) throws {
        if let httpResponse = response as? HTTPURLResponse {
            print("Status code: \(httpResponse.statusCode)")
            guard (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
        }
    }
    
    private func decode<T: Decodable>(_ data: Data) -> AnyPublisher<T, Error> {
        //Check if the respond is json or not
        if T.self == Data.self, let data = data as? T {
            return Just(data)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        return Just(data)
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error in
                print("Decoding error: \(error.localizedDescription)")
                return error
            }
            .eraseToAnyPublisher()
    }
}
