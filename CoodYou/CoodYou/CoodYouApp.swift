//
//  CoodYouApp.swift
//  CoodYou
//
//  Created by Hassam Gani on 27/09/25.
//

import SwiftUI

// This file intentionally delegates to the CampusDashApp entrypoint located in the CampusDash source.
// Keep this lightweight so Xcode's generated target can still use the app entry.

@main
struct CoodYouAppMain: App {
    var body: some Scene {
        WindowGroup {
            // Use the CampusDashApp's root view. If CampusDashApp is present in the project as @main,
            // Swift will error on duplicate @main. In that case, open the CampusDashApp.swift and
            // remove its @main attribute and let this file hold it. For now, if CampusDashApp exists
            // as a struct, instantiate its RootView directly.
            RootView().environmentObject(AppState())
        }
    }
}
