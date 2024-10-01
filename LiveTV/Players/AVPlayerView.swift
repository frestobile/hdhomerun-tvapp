//
//  AVPlayerView.swift
//  LiveTV
//
//  Created by CodingGuru on 9/25/24.
//

import Combine
import AVKit
import SwiftUI
import ffmpegkit
import GCDWebServer

struct AVPlayerView: UIViewControllerRepresentable {
    let streamURL: URL

    func makeUIViewController(context: Context) -> UIViewController {
        let playerVC = AVPlayerController(url: streamURL)
        return playerVC
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed
    }
}

class AVPlayerController: UIViewController {
    var player: AVPlayer?
    var isLoading = true
    var cancellables = Set<AnyCancellable>()
    var loadingTimer: AnyCancellable?
    
    var streamURL: URL
    var progressView: UIActivityIndicatorView?
    
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
        configureAudioSession()
        processStream() // Start processing stream with FFmpeg
        setupUI()
        setupAVPlayer() // Initialize AVPlayer immediately
        startLocalHTTPServer()
        
        let outputStreamURL = documentPath.appendingPathComponent(playlistName)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: setupPlayerWithPlaylist)
        
    }
    // Start local HTTP server to serve the HLS files
    func startLocalHTTPServer() {
        // Initialize the web server
        webServer = GCDWebServer()

        // Serve files from the Document directory (HLS playlist and segments)
        webServer.addGETHandler(forBasePath: "/", directoryPath: documentPath.path, indexFilename: nil, cacheAge: 3600, allowRangeRequests: true)
//        webServer.addHandler(forMethod: "GET", pathRegex: ".*\\.m3u8", request: GCDWebServerRequest.self) { (request) -> GCDWebServerResponse in
//            let path = self.documentPath.appendingPathComponent(request.path).path
//            return GCDWebServerFileResponse(file: path)!
//        }
//
//        webServer.addHandler(forMethod: "GET", pathRegex: ".*\\.ts", request: GCDWebServerRequest.self) { (request) -> GCDWebServerResponse in
//            let path = self.documentPath.appendingPathComponent(request.path).path
//            return GCDWebServerFileResponse(file: path)!
//        }
        // Start the web server on port 9000
        webServer.start(withPort: 9000, bonjourName: "Local WebServer")
        
        print("Local server started at: \(webServer.serverURL?.absoluteString ?? "")")
    }
    
    // Set up a loading indicator UI
    func setupUI() {
        let progressView = UIActivityIndicatorView(style: .large)
        progressView.center = self.view.center
        self.view.addSubview(progressView)
        progressView.startAnimating()
        self.progressView = progressView // Keep a reference to stop it later
    }
    
    // Configure the audio session
    func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
        }
    }
    
    // Process the stream using FFmpeg
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
                    self.isLoading = false
                    self.progressView?.stopAnimating() // Stop loading indicator
                }
            }
        }
    }
    
    // Set up the AVPlayer
    func setupAVPlayer() {
        // Create an AVPlayer instance without a URL initially
        self.player = AVPlayer()
    }

    // Wait for the playlist to become available and play
    func waitForPlaylist(outputURL: URL) {
        loadingTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                // Check if the playlist file exists
                if FileManager.default.fileExists(atPath: outputURL.path) {
                    print("Playlist file is available at path: \(outputURL.path)")
                    self.loadingTimer?.cancel() // Stop polling
                    self.loadingTimer = nil // Clean up timer
                    
                    // Setup the player with the playlist
                    self.setupPlayerWithPlaylist()
                } else {
                    print("Waiting for the playlist file to become available...")
                }
            }
        
        // Store the cancellable in the set to manage its lifecycle
        cancellables.insert(loadingTimer!) // Store the cancellable
    }

    // Setup the player with the playlist
    func setupPlayerWithPlaylist() {
        // URL to the .m3u8 playlist on the local HTTP server
        guard let serverURL = webServer.serverURL else {
            print("Web server is not running.")
            return
        }
//        let hlsURL = serverURL.appendingPathComponent(playlistNam)
        let hlsURL = serverURL.appendingPathComponent(playlistName)
        // Create an AVPlayerItem using the .m3u8 HLS playlist
        let playerItem = AVPlayerItem(url: hlsURL)
        self.player?.replaceCurrentItem(with: playerItem) // Set the new item

        // Observe the status of the player item
        playerItem.publisher(for: \.status)
            .receive(on: DispatchQueue.main) // Ensure UI updates happen on the main thread
            .sink { [weak self] status in
                guard let self = self else { return }
                switch status {
                case .readyToPlay:
                    print("Player is ready to play")
                    self.isLoading = false
                    self.progressView?.stopAnimating() // Stop loading indicator
                    self.player?.play() // Start playback when ready
                case .failed:
                    print("Player item failed with error: \(playerItem.error?.localizedDescription ?? "Unknown error")")
                    if let error = playerItem.error {
                        print("Detailed error information: \(error.localizedDescription)")
                    }
                    self.isLoading = false
                    self.progressView?.stopAnimating() // Stop loading indicator
                case .unknown:
                    self.isLoading = true
                @unknown default:
                    print("Unknown status encountered")
                    self.isLoading = false
                    self.progressView?.stopAnimating() // Stop loading indicator
                }
            }
            .store(in: &cancellables)


        // Add observer for player item playback status
        self.player?.addObserver(self, forKeyPath: "status", options: [.new, .old], context: nil)
    }

    // Observe player status changes
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status" {
            if let player = object as? AVPlayer {
                switch player.status {
                case .readyToPlay:
                    print("AVPlayer is ready to play")
                case .failed:
                    print("AVPlayer failed with error: \(player.error?.localizedDescription ?? "Unknown error")")
                case .unknown:
                    print("AVPlayer status is unknown")
                @unknown default:
                    print("Unknown AVPlayer status encountered")
                }
            }
        }
    }
}
