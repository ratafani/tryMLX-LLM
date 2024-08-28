//
//  RouteService.swift
//  MLX-ServerUI
//
//  Created by Muhammad Tafani Rabbani on 27/08/24.
//

import Foundation

protocol RouteService {
    var scheme: String { get }
    var host: String { get }
    var path: String { get }
}


