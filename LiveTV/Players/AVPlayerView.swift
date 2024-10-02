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
        documentPath = getDocumentsDirectory()
        checkAvailableStorage()
        processStream() // Start processing stream with FFmpeg
        setupAVPlayer() // Initialize AVPlayer immediately
        startLocalHTTPServer()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: setupPlayerWithPlaylist)
    }
    // Start local HTTP server to serve the HLS files
    func startLocalHTTPServer() {
        // Initialize the web server
        webServer = GCDWebServer()

        webServer.addGETHandler(forBasePath: "/", directoryPath: documentPath.path, indexFilename: nil, cacheAge: 3600, allowRangeRequests: true)

        webServer.start(withPort: 9090, bonjourName: "Local WebServer")
        
        print("Local server started at: \(webServer.serverURL?.absoluteString ?? "")")
    }
    
    func stopWebServer() {
        webServer?.stop()
    }
    
    // Process the stream using FFmpeg
    func processStream() {
        let inputUrlString = streamURL.absoluteString

        guard let outputDirectory = createHLSOutputDirectory() else {
            print("Failed to create output directory")
            return
        }
        
        let outputStreamURL = outputDirectory.appendingPathComponent(playlistName)
        
        // FFmpeg command to create HLS
        let ffmpegCommand = """
        -i \(inputUrlString) -codec: copy -start_number 0 -hls_time 5 -hls_list_size 5 -hls_flags delete_segments -f hls -hls_segment_filename "\(outputDirectory.appendingPathComponent("segment_%03d.ts").path)" "\(outputStreamURL.path)"
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
        let hlsURL = serverURL.appendingPathComponent("HLSOutput/\(playlistName)")
        print("Stream URL: \(hlsURL.absoluteString)")
        
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
                    self.player?.play() // Start playback when ready
                case .failed:
                    print("Player item failed with error: \(playerItem.error?.localizedDescription ?? "Unknown error")")
                    if let error = playerItem.error {
                        print("Detailed error information: \(error.localizedDescription)")
                    }
                    self.isLoading = false
                case .unknown:
                    self.isLoading = true
                @unknown default:
                    print("Unknown status encountered")
                    self.isLoading = false
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
    
    private func createHLSOutputDirectory() -> URL? {
        let fileManager = FileManager.default
        let outputDirectory = documentPath.appendingPathComponent("HLSOutput")

        if !fileManager.fileExists(atPath: outputDirectory.path) {
            do {
                try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true, attributes: nil)
                print("Directory created at: \(outputDirectory.path)")
            } catch {
                print("Failed to create directory: \(error)")
                return nil
            }
        }
        return outputDirectory
    }

    private func getDocumentsDirectory() -> URL {
//        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return FileManager.default.temporaryDirectory
    }
    
    func checkAvailableStorage() {
        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: getDocumentsDirectory().path)
            if let freeSpace = systemAttributes[.systemFreeSize] as? NSNumber {
                print("Available storage: \(freeSpace.int64Value / (1024 * 1024)) MB")
            }
        } catch {
            print("Error retrieving file system attributes: \(error)")
        }
    }
}
