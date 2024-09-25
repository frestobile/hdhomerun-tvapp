//
//  VideoPlayer.swift
//  LiveTV
//
//  Created by CodingGuru on 9/16/24.
//

import SwiftUI
import AVKit
import AVFoundation
import TVVLCKit

struct VideoPlayerView: UIViewRepresentable {
    var playerWrapper: VLCPlayerWrapper

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        // Safely unwrap drawable to avoid force unwrapping nil
       if let playerView = playerWrapper.mediaPlayer?.drawable as? UIView {
           view.addSubview(playerView)
           playerView.translatesAutoresizingMaskIntoConstraints = false

           NSLayoutConstraint.activate([
               playerView.topAnchor.constraint(equalTo: view.topAnchor),
               playerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
               playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
               playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
           ])
       } else {
           print("Error: mediaPlayer drawable is nil")
       }

//        playerWrapper.setupPiP(with: playerView) // Setup PiP
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // No-op
    }
}
