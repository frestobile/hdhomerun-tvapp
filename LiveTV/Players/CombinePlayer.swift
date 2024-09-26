//
//  CombinePlayer.swift
//  LiveTV
//
//  Created by CodingGuru on 9/25/24.
//

import UIKit
import TVVLCKit
import SwiftUI
import AVKit

struct CombinePlayer: UIViewControllerRepresentable {
    let streamURL: URL

    func makeUIViewController(context: Context) -> UIViewController {
        let playerVC = CombineController(url: streamURL)
        return playerVC
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Update the UI view controller if needed
    }
}

class CombineController: UIViewController, VLCMediaPlayerDelegate {
    
    var mediaPlayer = VLCMediaPlayer()
    var avPlayer = AVPlayer()
    var avPlayerLayer: AVPlayerLayer?
    
    var videoView: UIView = UIView()
    let streamURL: URL
    var statusLabel: UILabel = UILabel()  // Label for playback status feedback
    
    var progressBar = UIProgressView(progressViewStyle: .default)
    var activityIndicator: UIActivityIndicatorView = UIActivityIndicatorView(style: .large)
    
    // Time interval for fast forward/rewind (e.g., 10 seconds)
    let seekInterval: Int = 10000  // 10 seconds in milliseconds
    var currentTimeLabel = UILabel()  // Label to show current playing time
    var totalTimeLabel = UILabel()
    
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
        setupAVPlayerLayer()  // Set up the AVPlayerLayer for remote control
        setupGestureRecognizers()  // Set up gesture recognizers for rewind/forward
        setupStatusLabel()  // Set up the status label
        setupActivityIndicator()  // Set up activity indicator for loading
        setupUIComponents()
    }
    
    // MARK: - Setup the VLC player and delegate
    func setupPlayer() {
        videoView.frame = self.view.bounds
        self.view.addSubview(videoView)
        
        mediaPlayer.drawable = videoView
        let media = VLCMedia(url: streamURL)
        media.addOptions([
            "network-caching": 1000,
            "file-caching":2000,
            "live-caching": 3000,
            "clock-jitter": 0,
            "clock-synchro": 1,
//            "avcodec-hw": "any",
        ])
        mediaPlayer.media = media
        mediaPlayer.delegate = self  // Set the delegate to observe player state
        mediaPlayer.play()
        updateStatusLabel(with: "Loading...")
        activityIndicator.startAnimating()  // Show spinner when loading starts
    }
    
    // MARK: - Setup the AVPlayerLayer for remote control
    func setupAVPlayerLayer() {
        avPlayerLayer = AVPlayerLayer(player: avPlayer)  // Create AVPlayerLayer for control
        avPlayerLayer?.frame = videoView.bounds
        avPlayerLayer?.videoGravity = .resizeAspect
        
        if let avLayer = avPlayerLayer {
            videoView.layer.addSublayer(avLayer)  // Add AVPlayerLayer as overlay for controls
        }
    }
    
    // MARK: - Setup the activity indicator (spinner) for buffering/loading
    func setupActivityIndicator() {
        activityIndicator.center = self.view.center  // Place spinner at the center of the view
        activityIndicator.color = .white
        activityIndicator.hidesWhenStopped = true  // Automatically hide when stopped
        self.view.addSubview(activityIndicator)
    }
    
    // MARK: - Setup the label for playback status
    func setupStatusLabel() {
        statusLabel.frame = CGRect(x: 20, y: 20, width: 300, height: 50)
        statusLabel.textColor = .white
        statusLabel.font = UIFont.systemFont(ofSize: 24)
        statusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        statusLabel.textAlignment = .center
        statusLabel.layer.cornerRadius = 10
        statusLabel.clipsToBounds = true
        self.view.addSubview(statusLabel)
    }
    
    // MARK: - Setup Progress Bar and Time Labels
    func setupUIComponents() {
        // Set up progress bar (UIProgressView)
        progressBar.frame = CGRect(x: 20, y: self.view.bounds.height - 60, width: self.view.bounds.width - 40, height: 15)
        progressBar.progress = 0.0  // Initialize to 0 progress
        progressBar.tintColor = .blue
        self.view.addSubview(progressBar)
        
        // Set up current time label
        currentTimeLabel.frame = CGRect(x: 20, y: self.view.bounds.height - 90, width: 100, height: 20)
        currentTimeLabel.text = "00:00"
        currentTimeLabel.textColor = .white
        currentTimeLabel.font = UIFont.systemFont(ofSize: 20)
        self.view.addSubview(currentTimeLabel)
        
        // Set up total time label
        totalTimeLabel.frame = CGRect(x: self.view.bounds.width - 120, y: self.view.bounds.height - 90, width: 100, height: 20)
        totalTimeLabel.textColor = .white
        totalTimeLabel.textAlignment = .right
        totalTimeLabel.text = "--:--"
        totalTimeLabel.font = UIFont.systemFont(ofSize: 20)
        self.view.addSubview(totalTimeLabel)
    }
    
    // MARK: - Gesture recognizers for remote controls
    func setupGestureRecognizers() {
        // Play/Pause on Tap
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        tapGesture.allowedPressTypes = [NSNumber(value: UIPress.PressType.playPause.rawValue)]
        self.view.addGestureRecognizer(tapGesture)
        
        // Menu Tap
        let tapMenu = UITapGestureRecognizer(target: self, action: #selector(handleTapMenu(_:)))
        tapMenu.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue)]
        self.view.addGestureRecognizer(tapMenu)
        // Left Tap
        let tapRwind = UITapGestureRecognizer(target: self, action: #selector(handleTapLeft(_:)))
        tapRwind.allowedPressTypes = [NSNumber(value: UIPress.PressType.leftArrow.rawValue)]
        self.view.addGestureRecognizer(tapRwind)
        // Right Tap
        let tapForward = UITapGestureRecognizer(target: self, action: #selector(handleTapRight(_:)))
        tapForward.allowedPressTypes = [NSNumber(value: UIPress.PressType.rightArrow.rawValue)]
        self.view.addGestureRecognizer(tapForward)
        
        // Swipe Right for Fast Forward
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeGesture(_:)))
        swipeRight.direction = .right
        self.view.addGestureRecognizer(swipeRight)
        
        // Swipe Left for Rewind
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeGesture(_:)))
        swipeLeft.direction = .left
        self.view.addGestureRecognizer(swipeLeft)
    }
    
    // MARK: - Handle rewind, fast forward
    @objc func handleTapRight(_ gesture: UITapGestureRecognizer) {
        print("Tapped Right")
        seek(seconds: seekInterval, isForward: true)
        
//        mediaPlayer.jumpForward(10)
    }
    
    @objc func handleTapLeft(_ gesture: UITapGestureRecognizer) {
        print("Tapped Left")
        seek(seconds: seekInterval, isForward: false)
//        mediaPlayer.jumpBackward(10)
        
    }
    
    // MARK: - Handle tap gestures (Play/Pause)
    @objc func handleTapGesture(_ gesture: UITapGestureRecognizer) {
        print("Play/Pause")
        if mediaPlayer.isPlaying {
            mediaPlayer.pause()
            updateStatusLabel(with: "Paused")
        } else {
            mediaPlayer.play()
            updateStatusLabel(with: "Playing")
        }
        
    }
    
    // MARK: - Handle function for Menu tap
    @objc func handleTapMenu(_ gesture: UITapGestureRecognizer) {
        mediaPlayer.stop()
    }
    
    // MARK: - Handle swipe gestures for fast forward, rewind
    @objc func handleSwipeGesture(_ gesture: UISwipeGestureRecognizer) {
        
        switch gesture.direction {
        case .right:
            print("Swipe right!")
            seek(seconds: seekInterval, isForward: true)
            
        case .left:
            print("Swipe left!")
            seek(seconds: seekInterval, isForward: false)
            
        default:
            break
        }
    }
    
    //MARK: - Seek to a specific time in milliseconds
    func seek(seconds: Int, isForward: Bool) {
        guard let mediaLength = mediaPlayer.media?.length.intValue else { return }
        let currentTime = mediaPlayer.time.intValue
        var newTime = 0
        if isForward {
            newTime = Int(currentTime) + Int(seconds)
        } else {
            newTime = Int(currentTime) - Int(seconds)
        }
        
        mediaPlayer.time = VLCTime(int: Int32(max(0, min(newTime, Int(mediaLength)))))
        updateStatusLabel(with: isForward ? "Fast forward 10s" : "Rewind 10s")
    }
    
    // MARK: - Update the status label text
    func updateStatusLabel(with message: String) {
        statusLabel.text = message
        // Hide the label after 3 seconds unless buffering
        if message != "Buffering..." && message != "Loading..." {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                if self?.statusLabel.text != "Buffering..." && self?.statusLabel.text != "Loading..." {
                    self?.statusLabel.text = ""
                    self?.statusLabel.alpha = 0.0
                }
            }
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
    
//    // MARK: - VLCMediaPlayerDelegate Methods
//    func mediaPlayerStateChanged(_ aNotification: Notification) {
//        switch mediaPlayer.state {
//        case .opening:
//            updateStatusLabel(with: "Loading...")
//            activityIndicator.startAnimating()  // Show spinner while loading
//            
//        case .buffering:
//            updateStatusLabel(with: "Buffering...")
//            activityIndicator.startAnimating()  // Keep showing spinner while buffering
//            
//        case .playing:
//            updateStatusLabel(with: "Playing")
//            activityIndicator.stopAnimating()  // Hide spinner when playing
//            
//        case .ended, .error:
//            updateStatusLabel(with: "Stopped")
//            activityIndicator.stopAnimating()  // Hide spinner when stopped or error occurs
//            
//        default:
//            break
//        }
//    }
    
    func mediaPlayerTimeChanged(_ aNotification: Notification) {
        guard let totalTime = mediaPlayer.media?.length else {
            return
        }
        
        let current = mediaPlayer.time.intValue
        let total = totalTime.intValue
        
        // Update the progress bar
        let progress = Float(current) / Float(total)
        progressBar.setProgress(progress, animated: true)

        currentTimeLabel.text = formatTime(milliseconds: Int(current))
        totalTimeLabel.text = formatTime(milliseconds: Int(total))
    }
}

