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
// SwiftUI wrapper for AVPlayerViewController
struct VLCPlayerView: UIViewControllerRepresentable {
    let streamURL: URL

    // Create the AVPlayerViewController to play the stream
    func makeUIViewController(context: Context) -> UIViewController {
        let playerVC = VLCPlayerViewController(url: streamURL)
        return playerVC
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Nothing to update for now
    }
}

class VLCPlayerViewController: UIViewController, VLCMediaPlayerDelegate {
    var mediaPlayer = VLCMediaPlayer()
    var videoView: UIView = UIView()
    let streamURL: URL
    // Loading indicator for buffering
    var loadingIndicator: UIActivityIndicatorView!
    
    // Control buttons
    var playPauseButton: UIButton!
    var stopButton: UIButton!
    var rewindButton: UIButton!
    var fastForwardButton: UIButton!
//    var seekSlider: UISlider!

    // Progress bar for seek position
    var progressBar: UIProgressView!
    // Time labels
    var currentTimeLabel: UILabel!
    var totalTimeLabel: UILabel!

    // Gesture recognizers
    var swipeLeftGesture: UISwipeGestureRecognizer!
    var swipeRightGesture: UISwipeGestureRecognizer!
    
    // UIStackView for control buttons
    var controlStackView: UIStackView!

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
        setupControls()
        setupGestures()
        setupTimeLabels()
        
        setupLoadingIndicator()
        // Enable remote control events
        becomeFirstResponder()  // Enables receiving remote control events
    }
    
    override var canBecomeFirstResponder: Bool {
        return true  // Make the controller able to receive remote control events
    }
    // Step 1: Set up the player with VLC media
    func setupPlayer() {
        videoView.frame = self.view.bounds
        self.view.addSubview(videoView)
        
        mediaPlayer.drawable = videoView
        mediaPlayer.media = VLCMedia(url: streamURL)
        mediaPlayer.delegate = self
        mediaPlayer.play()
    }
    
    // Step 2: Set up player controls inside the video view with icons
    func setupControls() {
        // Create control buttons with icons
        playPauseButton = createIconButton(systemIconName: "playpause.fill", action: #selector(playPauseTapped))
        stopButton = createIconButton(systemIconName: "stop.fill", action: #selector(stopTapped))
        rewindButton = createIconButton(systemIconName: "gobackward.10", action: #selector(rewindTapped))
        fastForwardButton = createIconButton(systemIconName: "goforward.10", action: #selector(fastForwardTapped))

        // Progress Bar (replacing seek slider)
        progressBar = UIProgressView(progressViewStyle: .default)
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(progressBar)

        // Arrange control buttons using UIStackView
        controlStackView = UIStackView(arrangedSubviews: [rewindButton, playPauseButton, stopButton, fastForwardButton])
        controlStackView.axis = .horizontal
        controlStackView.distribution = .equalSpacing
        controlStackView.alignment = .center
        controlStackView.spacing = 20
        controlStackView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(controlStackView)

        Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(updateProgressBarAndTimeLabels), userInfo: nil, repeats: true)
        // Add constraints to position controls and progress bar inside the view
        setupConstraints()
    }

    // Helper function to create icon buttons
    func createIconButton(systemIconName: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        let icon = UIImage(systemName: systemIconName)
        button.setImage(icon, for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: action, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
    
    // Step 4: Setup Time Labels
    func setupTimeLabels() {
        // Current time label
        currentTimeLabel = UILabel(frame: CGRect(x: 20, y: self.view.bounds.height - 180, width: 150, height: 40))
        currentTimeLabel.textColor = .white
        currentTimeLabel.text = "00:00"
        self.view.addSubview(currentTimeLabel)

        // Total time label
        totalTimeLabel = UILabel(frame: CGRect(x: self.view.bounds.width - 120, y: self.view.bounds.height - 180, width: 150, height: 40))
        totalTimeLabel.textColor = .white
        totalTimeLabel.text = "--:--"
        self.view.addSubview(totalTimeLabel)
    }

    // Step 3: Setup Gesture Recognizers for swipe gestures on Apple TV remote
    func setupGestures() {
        // Swipe left to rewind
        swipeLeftGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeGesture(_:)))
        swipeLeftGesture.direction = .left
        self.view.addGestureRecognizer(swipeLeftGesture)

        // Swipe right to fast forward
        swipeRightGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeGesture(_:)))
        swipeRightGesture.direction = .right
        self.view.addGestureRecognizer(swipeRightGesture)
    }

    // Step 4: Handle Apple TV Remote Play/Pause Button
    override func remoteControlReceived(with event: UIEvent?) {
        if let event = event, event.type == .remoteControl {
            switch event.subtype {
            case .remoteControlPlay:
                mediaPlayer.play()
            case .remoteControlPause:
                mediaPlayer.pause()
            case .remoteControlTogglePlayPause:
                playPauseTapped() // Toggle between play and pause
            default:
                break
            }
        }
    }
    
    
    // Step 5: Button Actions

    @objc func playPauseTapped() {
        if mediaPlayer.isPlaying {
            mediaPlayer.pause()
        } else {
            mediaPlayer.play()
        }
    }

    @objc func stopTapped() {
        mediaPlayer.stop()
    }

    @objc func rewindTapped() {
        // Rewind by 10 seconds
        let currentTime = mediaPlayer.time.intValue
        let newTime = currentTime - 10000 // rewind 10 seconds (10000 ms)
        mediaPlayer.time = VLCTime(int: newTime)
    }

    @objc func fastForwardTapped() {
        // Fast forward by 10 seconds
        let currentTime = mediaPlayer.time.intValue
        let newTime = currentTime + 10000 // forward 10 seconds (10000 ms)
        mediaPlayer.time = VLCTime(int: newTime)
    }
    
    @objc func updateProgressBarAndTimeLabels() {
        let currentTime = mediaPlayer.time.intValue
        let duration = mediaPlayer.media!.length.intValue
        // Update the progress bar position
        progressBar.progress = Float(currentTime) / Float(duration)
        
        // Update the time labels
        currentTimeLabel.text = formatTime(Int(currentTime))
        totalTimeLabel.text = formatTime(Int(duration))
        
    }
    
    // Utility to format time in mm:ss format
    func formatTime(_ time: Int) -> String {
        let seconds = (time / 1000) % 60
        let minutes = (time / (1000 * 60)) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // Step 6: Handle Swipe Gestures
    @objc func handleSwipeGesture(_ gesture: UISwipeGestureRecognizer) {
        if gesture.direction == .left {
            rewindTapped() // Swipe left = Rewind
        } else if gesture.direction == .right {
            fastForwardTapped() // Swipe right = Fast Forward
        }
    }

    // Step 7: Setup a Loading Indicator for Buffering
    func setupLoadingIndicator() {
        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.color = .white
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(loadingIndicator)

        // Center the loading indicator in the middle of the screen
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: self.view.centerYAnchor)
        ])

        // Show the indicator initially (before video starts playing)
        loadingIndicator.startAnimating()
    }

    // Helper function to add constraints for control buttons and progress bar
    func setupConstraints() {
        // Constraints for control buttons stack view
        NSLayoutConstraint.activate([
            controlStackView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            controlStackView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])

        // Constraints for progress bar
        NSLayoutConstraint.activate([
            progressBar.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 20),
            progressBar.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -20),
            progressBar.bottomAnchor.constraint(equalTo: controlStackView.topAnchor, constant: -20)
        ])
    }
    
    // VLCMediaPlayerDelegate method to listen for media player state changes
    func mediaPlayerStateChanged(_ aNotification: Notification) {
        switch mediaPlayer.state {
        case .buffering:
                
            // Show the loading indicator when buffering or opening
            loadingIndicator.startAnimating()
            loadingIndicator.isHidden = false
            
        case .opening, .playing:
            // Hide the loading indicator when video starts playing
            loadingIndicator.stopAnimating()
            loadingIndicator.isHidden = true

        case .stopped, .ended, .error:
            // Handle other states if needed (like stopping the player or handling errors)
            loadingIndicator.stopAnimating()
            loadingIndicator.isHidden = false

        default:
            break
        }
    }
}
