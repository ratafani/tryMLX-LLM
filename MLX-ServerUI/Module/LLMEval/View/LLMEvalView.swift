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
    
    @StateObject var viewmodel = LLMEvalViewModel()
    @Environment(DeviceStatViewModel.self) private var deviceStat

    enum displayStyle: String, CaseIterable, Identifiable {
        case plain, markdown
        var id: Self { self }
    }

    @State private var selectedDisplayStyle = displayStyle.markdown

    var body: some View {
        VStack(alignment: .leading,spacing:0) {
            // show the model output
            ScrollView(.vertical) {
                ScrollViewReader { sp in
                    Group {
                        ForEach(viewmodel.conversationHistory.indices,id:\.self){ index in
                            let mes = viewmodel.conversationHistory[index]
                            
//                            Text(mes["role"] ?? "")
                            if let role = mes["role"]{
                                if role == "User"{
                                    HStack{
                                        Spacer()
                                        Text(mes["content"] ?? "")
                                            .padding(.horizontal)
                                            .padding(.vertical,8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .foregroundStyle(.blue)
                                            )
                                    }
                                }else{
                                    HStack{
                                        Text(mes["content"] ?? "")
                                            .padding(.horizontal)
                                            .padding(.vertical,8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .foregroundStyle(.gray)
                                            )
                                            .textSelection(.enabled)
                                        Spacer()
                                    }
                                }
                            }
                        }
                        if viewmodel.running{
                            HStack{
                                
                                Text(viewmodel.output)
                                    .padding(.horizontal)
                                    .padding(.vertical,8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .foregroundStyle(.gray)
                                    )
                                    .overlay(
                                            Group {
                                                if viewmodel.output.isEmpty {
                                                    ProgressView()
                                                        .progressViewStyle(LinearProgressViewStyle())
                                                } else {
                                                    EmptyView()
                                                }
                                            }
                                        )
                                    .textSelection(.enabled)
                                Spacer()
                            }
//                            Markdown(viewmodel.output)
//                                .textSelection(.enabled)
                        }else{
                            
                        }
                        
                        
                        
                    }
                    .onChange(of: viewmodel.output) { _, _ in
                        sp.scrollTo("bottom")
                    }

                    Spacer()
                        .frame(width: 1, height: 1)
                        .id("bottom")
                }
            }

            HStack {
                TextField("prompt", text: $viewmodel.prompt)
                    .onSubmit(generate)
                    .disabled(viewmodel.running)
                Button("generate", action: generate)
                    .disabled(viewmodel.running)
            }
        }
        
        .padding()
        
        .toolbar {
            ToolbarItem {
                Text(
                    "Model: \(viewmodel.modelInfo)"
                )
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
                        copyToClipboard(viewmodel.output)
                    }
                } label: {
                    Label("Start New Conversation", systemImage: "doc.fill.badge.plus")
                }
                .labelStyle(.titleAndIcon)
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        copyToClipboard(viewmodel.output)
                    }
                } label: {
                    Label("Copy Output", systemImage: "doc.on.doc.fill")
                }
                .disabled(viewmodel.output == "")
                .labelStyle(.titleAndIcon)
            }

        }
        .toolbarTitleDisplayMode(.inline)
        .task {
            self.viewmodel.prompt = viewmodel.modelConfiguration.defaultPrompt

            // pre-load the weights on launch to speed up the first generation
            _ = try? await viewmodel.load()
        }
    }

    private func generate() {
        Task {
            await viewmodel.generate()
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
