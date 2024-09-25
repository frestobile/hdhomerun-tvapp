//
//  SettingsView.swift
//  LiveTV
//
//  Created by CodingGuru on 9/7/24.
//

import SwiftUI

struct SettingsView: View {
    @State private var selectedSettingsMenu: SettingsMenu? = nil
    
    var body: some View {
        List {
            NavigationLink(
                destination: SourcesView(),
                tag: SettingsMenu.sources,
                selection: $selectedSettingsMenu
            ) {
                Text("Sources")
            }
            
            NavigationLink(
                destination: TunersView(),
                tag: SettingsMenu.tuners,
                selection: $selectedSettingsMenu
            ) {
                Text("Tuners")
            }
            
            NavigationLink(
                destination: PlaysettingView(),
                tag: SettingsMenu.playback,
                selection: $selectedSettingsMenu
            ) {
                Text("Playback")
            }
        }
        .navigationTitle("Settings")
    }
}

enum SettingsMenu: Hashable {
    case sources
    case tuners
    case playback
}

#Preview {
    SettingsView()
}

