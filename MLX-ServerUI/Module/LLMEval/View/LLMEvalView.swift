//
//  LLMEvalView.swift
//  MLX-ServerUI
//
//  Created by Muhammad Tafani Rabbani on 28/08/24.
//

import MLX
import MLXRandom
import MarkdownUI
//import Metal
import SwiftUI
import Tokenizers

struct LLMEvalView: View {

    @State var prompt = ""
    @StateObject var llm = LLMEvaluator()
    @Environment(DeviceStat.self) private var deviceStat

    enum displayStyle: String, CaseIterable, Identifiable {
        case plain, markdown
        var id: Self { self }
    }

    @State private var selectedDisplayStyle = displayStyle.markdown

    var body: some View {
        VStack(alignment: .leading) {
            VStack {
                HStack {
                    Text(llm.modelInfo)
                        .textFieldStyle(.roundedBorder)

                    Spacer()

                    Text(llm.stat)
                }
                HStack {
                    Spacer()
                    if llm.running {
                        ProgressView()
                            .frame(maxHeight: 20)
                        Spacer()
                    }
                    Picker("", selection: $selectedDisplayStyle) {
                        ForEach(displayStyle.allCases, id: \.self) { option in
                            Text(option.rawValue.capitalized)
                                .tag(option)
                        }

                    }
                    .pickerStyle(.segmented)
                    #if os(visionOS)
                        .frame(maxWidth: 250)
                    #else
                        .frame(maxWidth: 150)
                    #endif
                }
            }

            // show the model output
            ScrollView(.vertical) {
                ScrollViewReader { sp in
                    Group {
                        if selectedDisplayStyle == .plain {
                            Text(llm.output)
                                .textSelection(.enabled)
                        } else {
                            Markdown(llm.output)
                                .textSelection(.enabled)
                        }
                    }
                    .onChange(of: llm.output) { _, _ in
                        sp.scrollTo("bottom")
                    }

                    Spacer()
                        .frame(width: 1, height: 1)
                        .id("bottom")
                }
            }

            HStack {
                TextField("prompt", text: $prompt)
                    .onSubmit(generate)
                    .disabled(llm.running)
                    #if os(visionOS)
                        .textFieldStyle(.roundedBorder)
                    #endif
                Button("generate", action: generate)
                    .disabled(llm.running)
            }
        }
        #if os(visionOS)
            .padding(40)
        #else
            .padding()
        #endif
        .toolbar {
            ToolbarItem {
                Label(
                    "Memory Usage: \(deviceStat.gpuUsage.activeMemory.formatted(.byteCount(style: .memory)))",
                    systemImage: "info.circle.fill"
                )
                .labelStyle(.titleAndIcon)
                .padding(.horizontal)
                .help(
                    Text(
                        """
                        Active Memory: \(deviceStat.gpuUsage.activeMemory.formatted(.byteCount(style: .memory)))/\(GPU.memoryLimit.formatted(.byteCount(style: .memory)))
                        Cache Memory: \(deviceStat.gpuUsage.cacheMemory.formatted(.byteCount(style: .memory)))/\(GPU.cacheLimit.formatted(.byteCount(style: .memory)))
                        Peak Memory: \(deviceStat.gpuUsage.peakMemory.formatted(.byteCount(style: .memory)))
                        """
                    )
                )
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        copyToClipboard(llm.output)
                    }
                } label: {
                    Label("Copy Output", systemImage: "doc.on.doc.fill")
                }
                .disabled(llm.output == "")
                .labelStyle(.titleAndIcon)
            }

        }
        .task {
            self.prompt = llm.modelConfiguration.defaultPrompt

            // pre-load the weights on launch to speed up the first generation
            _ = try? await llm.load()
        }
    }

    private func generate() {
        Task {
            await llm.generate(prompt: prompt)
        }
    }
    private func copyToClipboard(_ string: String) {
        #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(string, forType: .string)
        #else
            UIPasteboard.general.string = string
        #endif
    }
}


class LLMEvaluator:ObservableObject {

    @Published var running = false

    @Published var output = ""
    @Published var modelInfo = ""
    @Published var stat = ""
    @Published var chatHistory : [String] = []
    
    private var conversationHistory: [[String: String]] = []

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
        var fullPrompt = "System: You are a helpful assistant. Always respond as the Assistant, never as the User. Include emojis in your responses.\n\n"
            
        
        for message in conversationHistory {
            if let role = message["role"], let content = message["content"] {
                fullPrompt += "\(role.capitalized): \(content)\n\n"
            }
        }
        
        fullPrompt += "Assistant: "
        
        return fullPrompt
    }
    
    @MainActor
    func generate(prompt: String) async {
        guard !running else { return }
        
        running = true
        self.output = ""
        conversationHistory.append(["role": "User", "content": prompt])
        do {
            let modelContainer = try await load()

            let newPrompt = preparePrompt()
            // augment the prompt as needed
            print(newPrompt)
//            let prompt = modelConfiguration.prepare(prompt: newPrompt)

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
                        if text.contains("User:") {
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
            conversationHistory.append(["role": "Assistant", "content": output])
            // update the text if needed, e.g. we haven't displayed because of displayEveryNTokens
            if result.output != self.output {
                self.output = result.output
            }
            self.stat = " Tokens/second: \(String(format: "%.3f", result.tokensPerSecond))"

        } catch {
            output = "Failed: \(error)"
        }

        running = false
    }
}
