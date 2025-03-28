//
//  LiveView.swift
//  LiveTV
//
//  Created by CodingGuru on 9/7/24.
//

import SwiftUI

struct LiveView: View {
    @StateObject private var model = HDHomeRunModel()
    let lineupUrl: String

    var body: some View {
        VStack {
            if model.isLoading {
                ProgressView("Fetching Channels...")
            } else if model.channels.isEmpty {
                Text("No Channels Available")
            } else {
                List {
                    ForEach(model.channels, id: \.GuideNumber) { channel in
                
                        NavigationLink(destination: ChannelDetailView(streamURL: channel.URL)) {
                            HStack {
                                Text("\(channel.GuideNumber) - \(channel.GuideName)")
                                Spacer()
                                if channel.HD == 1 {
                                    Text("HD")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            model.getChannelList(lineupUrl: lineupUrl)
        }
        .alert(isPresented: $model.showAlert) {
            Alert(
                title: Text("No HDHomeRun Channels Found"),
                message: Text("We couldn't find any HDHomeRun channels of the device. Please check your device."),
                dismissButton: .default(Text("OK"))
            )
        }
        .navigationTitle("Live TV")
    }
}

#Preview {
    LiveView(lineupUrl: "http://192.168.8.173/lineup.json")
}

