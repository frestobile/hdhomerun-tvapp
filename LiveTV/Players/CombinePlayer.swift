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
import GCDWebServer

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
    let seekInterval: Int32 = 10000  // 10 seconds in milliseconds
    var currentTimeLabel = UILabel()  // Label to show current playing time
    var totalTimeLabel = UILabel()
    
    var canSeek = false
    var isScrubbing = false
    var lastScrubTime: Int = 0
    
    let networkCache: Int = 10000 // Increase to 10 seconds for better rewind performance
    let fileCache: Int = 5000    // Increase to 10 seconds for local files
    let readTimeout: Int = 30000  // 60 seconds
    let bufferSize: Int = 102400
    let rtspFrameBufferSize: Int = 2048
    
    var webServer: GCDWebServer!
    let playlistName = "playlist.m3u8"
    var documentPath: URL!
    
    init(url: URL) {
        self.streamURL = url
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        processStream()
        setupAVPlayerLayer()  // Set up the AVPlayerLayer for remote control
        setupGestureRecognizers()  // Set up gesture recognizers for rewind/forward
        setupStatusLabel()  // Set up the status label
//        setupActivityIndicator()  // Set up activity indicator for loading
        setupUIComponents()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: setupPlayer)
    }
    
    // MARK: - Setup the VLC player and delegate
    func setupPlayer() {
        videoView.frame = self.view.bounds
        self.view.addSubview(videoView)
        
        mediaPlayer.drawable = videoView
//        let outputStreamURL = documentPath.appendingPathComponent(playlistName)
        let outputStreamURL = webServer.serverURL?.appendingPathComponent(playlistName)
        
        print(outputStreamURL?.absoluteString as Any)
        
        let media = VLCMedia(url: outputStreamURL!)

        media.addOption(":network-caching=\(networkCache)")
        media.addOption(":live-caching=\(networkCache)")
        media.addOption(":prefetch-buffer-size=\(bufferSize)")
        media.addOption(":rtsp-frame-buffer-size=\(rtspFrameBufferSize)")
        media.addOption(":read-timeout=\(readTimeout)")
        media.addOption(":rtsp-tcp")
        media.addOption(":drop-late-frames")
        media.addOption(":skip-frames")
        media.addOption(":clock-jitter=0")
        media.addOption(":clock-synchro=0")
        
        mediaPlayer.media = media
        mediaPlayer.delegate = self  // Set the delegate to observe player state
        mediaPlayer.play()
        updateStatusLabel(with: "Loading...")
//        activityIndicator.startAnimating()  // Show spinner when loading starts
//        checkStreamCapabilities()
    }
    
    // Start local HTTP server to serve the HLS files
    func startLocalHTTPServer() {
        webServer = GCDWebServer()
        // Serve files from the Document directory (HLS playlist and segments)
        webServer.addGETHandler(forBasePath: "/", directoryPath: documentPath.path, indexFilename: nil, cacheAge: 3600, allowRangeRequests: true)
        // Start the web server on port 9000
        webServer.start(withPort: 9000, bonjourName: "Local WebServer")
        print("Local server started at: \(webServer.serverURL?.absoluteString ?? "")")
    }
    
    // MARK: - Process the stream using FFmpeg
    func processStream() {
        let inputUrlString = streamURL.absoluteString

        let outputStreamURL = documentPath.appendingPathComponent(playlistName)
        
        // FFmpeg command to create HLS
        let ffmpegCommand = """
        -i \(inputUrlString) -codec: copy -start_number 0 -hls_time 5 -hls_list_size 0 -hls_flags delete_segments -f hls -hls_segment_filename "\(documentPath.appendingPathComponent("segment_%03d.ts").path)" "\(outputStreamURL.path)"
        """

        // Execute the FFmpeg command
        FFmpegKit.executeAsync(ffmpegCommand) { [weak self] session in
            guard let self = self else { return }
            let returnCode = session?.getReturnCode()
            
            // Log the FFmpeg output
            session?.getLogs()?.forEach { log in
                print((log as AnyObject).getMessage() as Any)
            }
            
            // Ensure FFmpeg processing succeeded
            if ReturnCode.isSuccess(returnCode) {
                print("FFmpeg processing succeeded.")
//                DispatchQueue.main.async {
//                    self.waitForPlaylist(outputURL: outputStreamURL) // Wait for the playlist to be ready
//                }
            } else {
                print("FFmpeg processing failed with return code: \(String(describing: returnCode))")
                DispatchQueue.main.async {
//                    self.activityIndicator.stopAnimating() // Stop loading indicator
                }
            }
        }
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
    
    // Check if the stream is live and whether it supports seeking
    func checkStreamCapabilities() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if self.mediaPlayer.media!.length.intValue <= 0 {
                // Length is unknown, likely a live stream
                self.canSeek = false
            } else {
                // Stream has a known length, determine if it's seekable
                self.canSeek = self.mediaPlayer.isSeekable
            }

            if !self.canSeek {
                print("The stream does not support seeking")
            }
        }
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
        
        // Scrubbing forward/backward with pan gesture
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        self.view.addGestureRecognizer(panGesture)
    }
    
    // MARK: - Handle panGesture
    @objc func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        print("Pan Gesture")
        let velocity = gesture.velocity(in: self.view)
        let translation = gesture.translation(in: self.view)
        
        // Horizontal swipe detected
        if abs(translation.x) > abs(translation.y) {
            if gesture.state == .began {
                isScrubbing = true
                lastScrubTime = Int(mediaPlayer.time.intValue / 1000) // Current time in seconds
            }

            // Update scrubbing based on swipe direction
            if isScrubbing {
                let scrubAmount = Int(translation.x / 10) // Adjust sensitivity
                let newTime = max(0, lastScrubTime + scrubAmount)
                scrub(to: newTime)
            }

            if gesture.state == .ended {
                isScrubbing = false
            }
        }
    }
    
    func scrub(to timeInSeconds: Int) {
        mediaPlayer.time = VLCTime(number: NSNumber(value: timeInSeconds * 1000))
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
        print("stop")
        mediaPlayer.stop()
        self.dismiss(animated: true, completion: nil)
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
    func seek(seconds: Int32, isForward: Bool) {
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

