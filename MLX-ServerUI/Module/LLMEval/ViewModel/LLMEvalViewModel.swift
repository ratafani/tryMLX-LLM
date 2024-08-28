//
//  LLMEvalViewModel.swift
//  MLX-ServerUI
//
//  Created by Muhammad Tafani Rabbani on 28/08/24.
//

import Foundation
import MLX
import MLXRandom



class LLMEvalViewModel:ObservableObject {
    
    @Published var running = false
    @Published var prompt = ""
    @Published var output = ""
    @Published var modelInfo = ""
    @Published var stat = ""
    
    
    @Published var conversationHistory: [[String: String]] = []
    
    /// this controls which model loads -- phi4bit is one of the smaller ones so this will fit on
    /// more devices
    let modelConfiguration = ModelConfiguration.llama3_1_8B_4bit
    
    /// parameters controlling the output
    let generateParameters = GenerateParameters(temperature: 0.6)
    let maxTokens = 3000
    
    /// update the display every N tokens -- 4 looks like it updates continuously
    /// and is low overhead.  observed ~15% reduction in tokens/s when updating
    /// on every token
    let displayEveryNTokens = 2
    
    enum LoadState {
        case idle
        case loaded(ModelContainer)
    }
    
    @Published var loadState = LoadState.idle
    
    /// load and return the model -- can be called multiple times, subsequent calls will
    /// just return the loaded model
    func load() async throws -> ModelContainer {
        switch loadState {
        case .idle:
            // limit the buffer cache
            MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)
            
            let modelContainer = try await loadModelContainer(configuration: modelConfiguration)
            {
                [modelConfiguration] progress in
                Task { @MainActor in
                    self.modelInfo =
                    "Downloading \(modelConfiguration.name): \(Int(progress.fractionCompleted * 100))%"
                }
            }
            self.modelInfo =
            "Loaded \(modelConfiguration.id).  Weights: \(MLX.GPU.activeMemory / 1024 / 1024)M"
            loadState = .loaded(modelContainer)
            return modelContainer
            
        case .loaded(let modelContainer):
            return modelContainer
        }
    }
    
    func preparePrompt() -> String {
        var fullPrompt = "System: You are a helpful assistant. Always respond as the Assistant, never as the User. Include emojis in your responses, end every answer with \"IENDMYTURNANDTHISISBREAKPOINT!\" right after the last letter of your answer with no space or new line before it. \n\n"
        
        
        for message in conversationHistory {
            if let role = message["role"], let content = message["content"] {
                fullPrompt += "\(role.capitalized): \(content)\n\n"
            }
        }
        
        fullPrompt += "Assistant: "
        
        return fullPrompt
    }
    
    @MainActor
    func generate() async {
        guard !running else { return }
        
        running = true
        self.output = ""
        conversationHistory.append(["role": "User", "content": prompt])
        
        do {
            let modelContainer = try await load()
            
            let newPrompt = preparePrompt()
            // augment the prompt as needed
            // let prompt = modelConfiguration.prepare(prompt: newPrompt)
            
            let promptTokens = await modelContainer.perform { _, tokenizer in
                tokenizer.encode(text: newPrompt)
            }
            
            // each time you generate you will get something new
            MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))
            
            let result = await modelContainer.perform { model, tokenizer in
                evaluate_generate(
                    promptTokens: promptTokens, parameters: generateParameters, model: model,
                    tokenizer: tokenizer, extraEOSTokens: modelConfiguration.extraEOSTokens
                ) { tokens in
                    // update the output -- this will make the view show the text as it generates
                    
                    if tokens.count % displayEveryNTokens == 0 {
                        let text = tokenizer.decode(tokens: tokens)
                        if text.contains("IENDMYTURNANDTHISISBREAKPOINT") || text.contains("User:") {
                            return .stop
                        }else{
                            Task { @MainActor in
                                self.output = text
                            }
                        }
                        
                    }
                    
                    if tokens.count >= maxTokens {
                        return .stop
                    } else {
                        return .more
                    }
                }
            }
            let parsed = result.output.replacingOccurrences(of: "IENDMYTURNANDTHISISBREAKPOINT", with: "")
            // update the text if needed, e.g. we haven't displayed because of displayEveryNTokens
            if parsed != self.output {
                self.output = parsed
            }
            conversationHistory.append(["role": "Assistant", "content": output])
            self.stat = " Tokens/second: \(String(format: "%.3f", result.tokensPerSecond))"
            
        } catch {
            output = "Failed: \(error)"
        }
        
        running = false
    }
}
