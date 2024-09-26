//
//  VLCPlayerWrapper.swift
//  LiveTV
//
//  Created by CodingGuru on 9/22/24.
//


import AVKit
import TVVLCKit
import UIKit
import SwiftUI

struct VLCPlayerControl: UIViewControllerRepresentable {
    let streamURL: URL

    func makeUIViewController(context: Context) -> UIViewController {
        let playerVC = VLCPlayerController(url: streamURL)
        return playerVC
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Update the UI view controller if needed
    }
}

class VLCPlayerController: UIViewController, VLCMediaPlayerDelegate {
    var mediaPlayer = VLCMediaPlayer()
    var videoView: UIView = UIView()
    let streamURL: URL
    var statusLabel: UILabel = UILabel()  // Label for playback status feedback
    
    // Activity indicator (spinner) for loading/buffering
    var activityIndicator: UIActivityIndicatorView = UIActivityIndicatorView(style: .large)
    
    // Variable to track scrubbing state
    var isScrubbing = false
    var lastScrubTime: VLCTime?
    
    var statusTimer: Timer?
    
    init(url: URL) {
        self.streamURL = url
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupPlayer()
        setupGestureRecognizers()  // Set up gesture recognizers
        setupStatusLabel()  // Set up the status label
        setupActivityIndicator()  // Set up activity indicator for loading
        
//        startStatusTimer()
    }
    
    func setupPlayer() {
        videoView.frame = self.view.bounds
        self.view.addSubview(videoView)
        
        mediaPlayer.drawable = videoView
        mediaPlayer.media = VLCMedia(url: streamURL)
        mediaPlayer.delegate = self
        mediaPlayer.play()
        updateStatusLabel(with: "Playing")
    }
    
    // MARK: - VLCMediaPlayerDelegate: Called when the media player's state changes
    func mediaPlayerStateChanged(_ aNotification: Notification) {
        switch mediaPlayer.state {
        case .opening:
            updateStatusLabel(with: "Loading...")
            activityIndicator.startAnimating()  // Show spinner while loading

        case .buffering:
            updateStatusLabel(with: "Buffering...")
            activityIndicator.startAnimating()  // Keep showing spinner while buffering

        case .playing:
            updateStatusLabel(with: "Playing")
            activityIndicator.stopAnimating()  // Hide spinner when playing

        case .ended, .error:
            updateStatusLabel(with: "Stopped")
            activityIndicator.stopAnimating()  // Hide spinner when stopped or error occurs

        default:
            break
        }
    }
    

    // MARK: - Helper Method to Format Time
    func formatTime(milliseconds: Int) -> String {
        let seconds = (milliseconds / 1000) % 60
        let minutes = (milliseconds / (1000 * 60)) % 60
        let hours = milliseconds / (1000 * 60 * 60)
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    // MARK: - Gesture recognizers for remote controls
    func setupGestureRecognizers() {
        // Play/Pause on Tap
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        tapGesture.allowedPressTypes = [NSNumber(value: UIPress.PressType.playPause.rawValue)]
        self.view.addGestureRecognizer(tapGesture)
        
        let tapRewind = UITapGestureRecognizer(target: self, action: #selector(handleRewindGesture(_:)))
        tapRewind.allowedPressTypes = [NSNumber(value: UIPress.PressType.leftArrow.rawValue)]
        self.view.addGestureRecognizer(tapRewind)
        
        let tapForward = UITapGestureRecognizer(target: self, action: #selector(handleFastForwardGesture(_:)))
        tapForward.allowedPressTypes = [NSNumber(value: UIPress.PressType.leftArrow.rawValue)]
        self.view.addGestureRecognizer(tapForward)
        
        
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeGesture(_:)))
        swipeRight.direction = .right
        self.view.addGestureRecognizer(swipeRight)

        // Swipe Left for Rewind
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeGesture(_:)))
        swipeLeft.direction = .left
        self.view.addGestureRecognizer(swipeLeft)
    
    }
    
    // Handle tap gestures (Play/Pause)
    @objc func handleTapGesture(_ gesture: UITapGestureRecognizer) {
        
        if mediaPlayer.isPlaying {
            mediaPlayer.pause()
            updateStatusLabel(with: "Paused")
        } else {
            mediaPlayer.play()
            updateStatusLabel(with: "Playing")
        }
    }
    
    @objc func handleFastForwardGesture(_ gesture: UISwipeGestureRecognizer) {
        let time = mediaPlayer.time
        let newTime = time.intValue + 10000
        seekToTime(newTime: Int(Int32(newTime)))
    }

    @objc func handleRewindGesture(_ gesture: UISwipeGestureRecognizer) {
        let time = mediaPlayer.time
        let newTime = time.intValue - 10000
        seekToTime(newTime: Int(Int32(newTime)))
    }
    
    // MARK: - Handle swipe gestures for fast forward, rewind, or scrubbing
    @objc func handleSwipeGesture(_ gesture: UISwipeGestureRecognizer) {
        let time = mediaPlayer.time
        print(gesture.direction.self)
        
        switch gesture.direction {
               
            case .right:
                // Scrub forward (optional)
                let newPosition = mediaPlayer.position + 0.05  // Move forward by 5%
                mediaPlayer.position = min(newPosition, 1.0)
                updateStatusLabel(with: "Scrubbing Forward")
                
            case .left:
                // Scrub backward (optional)
                let newPosition = mediaPlayer.position - 0.05  // Move backward by 5%
                mediaPlayer.position = max(newPosition, 0.0)
                updateStatusLabel(with: "Scrubbing Backward")
            case .up, .down:
                if !isScrubbing {
                    startBuffering()
                }
                handleScrubbing(gesture.direction == .up)
                
            default:
                break
        }
        
    }
    
    // Begin buffering during scrubbing
   func startBuffering() {
       isScrubbing = true
       lastScrubTime = mediaPlayer.time
       mediaPlayer.pause()  // Pause playback during scrubbing
       updateStatusLabel(with: "Buffering...")
       activityIndicator.startAnimating()  // Show spinner while scrubbing
   }
   
   // Perform scrubbing (up to move forward, down to move backward)
   func handleScrubbing(_ isForward: Bool) {
//        let time = mediaPlayer.time
           let newPosition = mediaPlayer.position + (isForward ? 0.05 : -0.00)
           mediaPlayer.position = max(min(newPosition, 1.0), 0.0)  // Ensure position is within bounds
           updateStatusLabel(with: "Scrubbing \(isForward ? "Forward" : "Backward")")
       
   }
   
   // End scrubbing and resume playback
   func endBuffering() {
       isScrubbing = false
       mediaPlayer.play()  // Resume playback
       updateStatusLabel(with: "Playing")
       activityIndicator.stopAnimating()  // Hide spinner after scrubbing ends
   }
   
   // Setup the activity indicator (spinner) for buffering/loading
   func setupActivityIndicator() {
       activityIndicator.center = self.view.center  // Place spinner at the center of the view
       activityIndicator.color = .white
       activityIndicator.hidesWhenStopped = true  // Automatically hide when stopped
       self.view.addSubview(activityIndicator)
   }
    
    // Seek to a specific time in milliseconds
    func seekToTime(newTime: Int) {
        guard let mediaLength = mediaPlayer.media?.length else { return }
        
        // Ensure we don't seek beyond the media length or before 0
        let clampedTime = max(0, min(newTime, Int(mediaLength.intValue)))
        mediaPlayer.time = VLCTime(int: Int32(clampedTime))  // Seek to the new time
    }

    // Setup the feedback label for playback status
    func setupStatusLabel() {
        statusLabel.frame = CGRect(x: 20, y: 20, width: 200, height: 50)
        statusLabel.textColor = .white
        statusLabel.font = UIFont.systemFont(ofSize: 24)
        statusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        statusLabel.textAlignment = .center
        statusLabel.layer.cornerRadius = 10
        statusLabel.clipsToBounds = true
        self.view.addSubview(statusLabel)
    }
    
    // Update the status label text
    func updateStatusLabel(with message: String) {
        statusLabel.text = message
        // Hide the label after 3 seconds
        if message != "Buffering..." && message != "Loading..." {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                if self?.statusLabel.text != "Buffering..." && self?.statusLabel.text != "Loading..." {
                    self?.statusLabel.text = ""
                    self?.statusLabel.alpha = 0.0
                }
            }
        }
    }
}
