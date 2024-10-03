//
//  TrackSelectionView.swift
//  LiveTV
//
//  Created by CodingGuru on 10/2/24.
//

import SwiftUI

struct TrackSelectionView: View {
    @StateObject var avController: AVPlayerController

    var body: some View {
        VStack {
            Text("Audio Tracks").font(.headline)
            if avController.audioOptions.isEmpty {
                Text("No Audio Tracks Available")
            } else {
                List(avController.audioOptions, id: \.self) { option in
                    Button(action: {
                        avController.selectAudioTrack(option)
                    }) {
                        HStack {
                            Text(option.displayName)
                            if option == avController.selectedAudioOption {
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }

            Text("Subtitle Tracks").font(.headline)
            if avController.subtitleOptions.isEmpty {
                Text("No Subtitle Tracks Available")
            } else {
                List(avController.subtitleOptions, id: \.self) { option in
                    Button(action: {
                        avController.selectSubtitleTrack(option)
                    }) {
                        HStack {
                            Text(option.displayName)
                            if option == avController.selectedSubtitleOption {
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.7))  // Dark background to make it look like an overlay
        .foregroundColor(.white)  // Text color
    }
}
