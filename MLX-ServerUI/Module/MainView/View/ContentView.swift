//
//  ContentView.swift
//  MLX-ServerUI
//
//  Created by Muhammad Tafani Rabbani on 27/08/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject var vm = MainViewModel(llmService: LLMManager(networkService: NetworkManager()))
    var body: some View {
        VStack {
            
            HStack {
                TextField(text: $vm.textfield) {
                    
                }
                Button("Send"){
                    vm.chat(message: vm.textfield)
                }
            }
            switch vm.viewState {
            case .idle:
                Text("idle")
            case .loading:
                Text("Loading")
            case .loaded(let array):
                ScrollView{
                    VStack{
                        ForEach(array,id: \.self){s in
                                Text(s)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
            case .error(let error):
                Text(error.localizedDescription)
            }
            
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
