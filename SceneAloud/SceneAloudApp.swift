//
//  SceneAloudApp.swift
//  SceneAloud
//
//  Created by Lucy Brown on 12/30/24.
//

import SwiftUI

@main
struct SceneAloudApp: App {
    @StateObject private var library = LibraryManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(library)
        }
    }
}
