//
//  MLX_ServerUIApp.swift
//  MLX-ServerUI
//
//  Created by Muhammad Tafani Rabbani on 27/08/24.
//

import SwiftUI

@main
struct MLX_ServerUIApp: App {
    var body: some Scene {
        WindowGroup {
            LLMEvalView()
                .environment(DeviceStatViewModel())
        }
    }
}
