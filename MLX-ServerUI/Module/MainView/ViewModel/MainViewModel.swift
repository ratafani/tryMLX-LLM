//
//  MainViewModel.swift
//  MLX-ServerUI
//
//  Created by Muhammad Tafani Rabbani on 27/08/24.
//

import SwiftUI
import Combine

enum ViewState {
    case idle
    case loading
    case loaded([String])
    case error(Error)
}
class MainViewModel:ObservableObject{
    @Published var viewState: ViewState = .idle
    @Published var port:String = "8080"
    @Published var textfield = ""
    @Published var chatHistory : [String] = []
   
    private var conversationHistory: [[String: String]] = []
    
    private let llmService: LLMService
    private var cancellables = Set<AnyCancellable>()
    
    init(llmService: LLMService) {
        self.llmService = llmService
    }
    
    func setupPort(port:String){
        self.port = port
    }
    
    func chat(message:String){
        
        conversationHistory.append(["role": "user", "content": message])
        
        let requestBody: [String: Any] = [
            "messages": conversationHistory,
            "temperature": 0.7,
            "max_tokens": 1000,
//            "stream": true
        ]
        
        
        viewState = .loading
        
        llmService.fetchResponse(args: requestBody, port: port)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.viewState = .error(error)
                }
            } receiveValue: { [weak self] response in
                guard let self else {return}
                
                withAnimation {
//                    temp = temp + (response.choices.first?.delta.content ?? "")
//                    self.conversationHistory.append(["role": "assistant", "content": temp])
//                    self.chatHistory[self.chatHistory.count - 1] = temp
//                    self.viewState = .loaded(self.chatHistory)
                    if let message = response.choices.first?.message.content{
                        self.conversationHistory.append(["role": "assistant", "content": message])
                        self.chatHistory.append(message)
                        self.viewState = .loaded(self.chatHistory)
                    }

                    
                }
            }
            .store(in: &cancellables)
    }
}
