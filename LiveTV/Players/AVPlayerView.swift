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
    var playerLayer: AVPlayerLayer?
    var playerViewController: AVPlayerViewController!
    var statusLabel: UILabel = UILabel()  // Label for playback status feedback
    
    var isLoading = true
    var cancellables = Set<AnyCancellable>()
    var loadingTimer: AnyCancellable?
    var streamURL: URL
    var progressView: UIActivityIndicatorView?
    
    var webServer: GCDWebServer!
    let playlistName = "playlist.m3u8"
    private var ffmpegSession: FFmpegSession?
    
    init(url: URL) {
        self.streamURL = url
        super.init(nibName: nil, bundle: nil)
        deleteHLSOutputFolder()
        processStream() // Start processing stream with FFmpeg
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        checkAvailableStorage()
        startLocalHTTPServer()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: waitForPlaylist)
    }
    
    // Set up a loading indicator UI
    func setupUI() {
        let progressView = UIActivityIndicatorView(style: .large)
        progressView.center = self.view.center
        self.view.addSubview(progressView)
        progressView.startAnimating()
        self.progressView = progressView // Keep a reference to stop it later
        
        statusLabel.frame = CGRect(x: 20, y: 20, width: 300, height: 50)
        statusLabel.textColor = .white
        statusLabel.font = UIFont.systemFont(ofSize: 24)
        statusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        statusLabel.textAlignment = .center
        statusLabel.layer.cornerRadius = 10
        statusLabel.clipsToBounds = true
        self.view.addSubview(statusLabel)
        updateStatusLabel(with: "Loading...")
    }
    
    //MARK: - Start local HTTP server to serve the HLS files
    func startLocalHTTPServer() {
        // Initialize the web server
        webServer = GCDWebServer()

        webServer.addGETHandler(forBasePath: "/", directoryPath: getDocumentsDirectory().path, indexFilename: nil, cacheAge: 3600, allowRangeRequests: true)

        webServer.start(withPort: 9090, bonjourName: "Local WebServer")
        
        print("Local server started at: \(webServer.serverURL?.absoluteString ?? "")")
    }
    
    func stopWebServer() {
        webServer?.stop()
        webServer = nil
    }
    
    //MARK: - Process the stream using FFmpeg
    func processStream() {
        let inputUrlString = streamURL.absoluteString

        guard let outputDirectory = createHLSOutputDirectory() else {
            print("Failed to create output directory")
            return
        }
        
        let outputStreamURL = outputDirectory.appendingPathComponent(playlistName)
        
        // FFmpeg command to create HLS
        let ffmpegCommand = """
                -i \(inputUrlString) -c:v h264_videotoolbox -b:v 5000k -c:a aac -b:a 128k -ac 2 -start_number 0 -hls_time 5 -hls_list_size 0 -hls_flags delete_segments -f hls -hls_segment_filename "\(outputDirectory.appendingPathComponent("segment_%03d.ts").path)" "\(outputStreamURL.path)"
                """

        // Execute the FFmpeg command
        self.ffmpegSession = FFmpegKit.executeAsync(ffmpegCommand) { [weak self] session in
            guard let self = self else { return }
            let returnCode = session?.getReturnCode()
            
            // Log the FFmpeg output
            session?.getLogs()?.forEach { log in
                print((log as AnyObject).getMessage() as Any)
            }
            
            // Ensure FFmpeg processing succeeded
            if ReturnCode.isSuccess(returnCode) {
                print("FFmpeg processing succeeded.")
            } else {
                print("FFmpeg processing failed with return code: \(String(describing: returnCode))")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.progressView?.stopAnimating()
                }
            }
        }
    }

    //MARK: - AVPlayer setup
    // Wait for the playlist to become available and play
    func waitForPlaylist() {
        guard let outputDirectory = createHLSOutputDirectory() else {
            print("Failed to create output directory")
            return
        }
        let outputURL = outputDirectory.appendingPathComponent(playlistName)
        
        loadingTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                // Check if the playlist file exists
                if FileManager.default.fileExists(atPath: outputURL.path) {
                    print("Playlist file is available at path: \(outputURL.path)")
                    self.loadingTimer?.cancel() // Stop polling
                    self.loadingTimer = nil // Clean up timer
                    
                    // Setup the server with the playlist
                    self.setupWebserverPlaylist()
                } else {
                    print("Waiting for the playlist file to become available...")
                }
            }
        cancellables.insert(loadingTimer!) // Store the cancellable
    }

    // Get stream URL with the playlist
    func setupWebserverPlaylist() {
        // URL to the .m3u8 playlist on the local HTTP server
        guard let serverURL = webServer.serverURL else {
            print("Web server is not running.")
            return
        }
        let hlsURL = serverURL.appendingPathComponent("HLSOutput/\(playlistName)")
        print("Stream URL: \(hlsURL.absoluteString)")
        
        setupPlayer(with: hlsURL)
        
    }
    
    // Setup AVPlayer with stream URL
    func setupPlayer(with url: URL) {
        player = AVPlayer(url: url)
//        playerLayer = AVPlayerLayer(player: player)

        playerViewController = AVPlayerViewController()
        playerViewController.player = player
        playerViewController.showsPlaybackControls = true  // Enable default playback controls

        // Add AVPlayerViewController as a child to this custom controller
        addChild(playerViewController)
        view.addSubview(playerViewController.view)

        // Set the playerViewController's frame to match the view
        playerViewController.view.frame = view.bounds
        playerViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        playerViewController.didMove(toParent: self)

//        playerLayer?.videoGravity = .resizeAspect
//        playerLayer?.cornerRadius = 10
//        playerLayer?.masksToBounds = true

        // Add the playerLayer to the view's layer
//        if let playerLayer = playerLayer {
//           view.layer.addSublayer(playerLayer)
//        }

        updateStatusLabel(with: "Playing...")
        // Start playback
        player?.play()
        progressView?.stopAnimating()
        isLoading = false
        // Observer for player's status, e.g., ready to play
        player?.addObserver(self, forKeyPath: "status", options: [.new, .initial], context: nil)
   }

    //MARK: - Observe player status changes
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
    
//    override func viewDidLayoutSubviews() {
//        super.viewDidLayoutSubviews()
//        playerLayer?.frame = view.bounds
//    }
    
    //MARK: - Control playback actions
    func play() {
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    func seek(to time: CMTime) {
        player?.seek(to: time)
    }

    //MARK: - Clean up when the view is deallocated
    deinit {
        self.stopWebServer()
        player?.pause()
        player?.removeObserver(self, forKeyPath: "status")
        player = nil
        self.ffmpegSession?.cancel()
        self.ffmpegSession = nil
//        self.cleanupOldSegments()
        self.deleteHLSOutputFolder()
        
        self.progressView?.stopAnimating()
    }
    
    //MARK: - Local storage access
    private func createHLSOutputDirectory() -> URL? {
        let fileManager = FileManager.default
        let outputDirectory = getDocumentsDirectory().appendingPathComponent("HLSOutput")

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
        return FileManager.default.temporaryDirectory
    }
    
    //MARK: - Check storage available
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
    
    func deleteHLSOutputFolder() {
        let fileManager = FileManager.default
        let tmpDirectory = NSTemporaryDirectory()
        
        // Path to the "HLSOutput" subfolder in the tmp directory
        let hlsOutputPath = (tmpDirectory as NSString).appendingPathComponent("HLSOutput")
        
        // Check if the folder exists
        if fileManager.fileExists(atPath: hlsOutputPath) {
            do {
                // Delete the folder and all its contents
                try fileManager.removeItem(atPath: hlsOutputPath)
                print("HLSOutput folder deleted successfully.")
            } catch {
                print("Failed to delete HLSOutput folder: \(error.localizedDescription)")
            }
        } else {
            print("HLSOutput folder does not exist.")
        }
    }
    
    //MARK: - Clean the segments files when player is closed
    func cleanupOldSegments() {
        guard let outputDirectory = createHLSOutputDirectory() else {
            print("Failed to create output directory")
            return
        }
        let playlistUrl = outputDirectory.appendingPathComponent(playlistName)

        // Get the list of segments currently in the playlist
        let activeSegments = getSegmentsFromPlaylist(playlistUrl: playlistUrl)
        
        do {
            // List all files in the HLS output directory
            let allFiles = try FileManager.default.contentsOfDirectory(atPath: outputDirectory.path)
            
            // Filter out only the .ts files (segments)
            let segmentFiles = allFiles.filter { $0.hasSuffix(".ts") }
            
            for segment in segmentFiles {
                // If a segment is not in the current playlist, delete it
                if !activeSegments.contains(segment) {
                    let segmentUrl = outputDirectory.appendingPathComponent(segment)
                    try FileManager.default.removeItem(at: segmentUrl)
                    print("Deleted old segment: \(segment)")
                }
            }
        } catch {
            print("Error during cleanup: \(error)")
        }
    }
    
    func getSegmentsFromPlaylist(playlistUrl: URL) -> [String] {
        do {
            let playlistContents = try String(contentsOf: playlistUrl, encoding: .utf8)
            let lines = playlistContents.split(separator: "\n")
            let segmentFiles = lines.filter { $0.hasSuffix(".ts") }
            return segmentFiles.map { String($0) }
        } catch {
            print("Error reading playlist: \(error)")
            return []
        }
    }
    
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
}

extension AVPlayerController {
    func selectAudioTrack(_ languageCode: String) {
        guard let currentItem = player?.currentItem,
              let group = currentItem.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else {
            return
        }

        for option in group.options {
            if option.extendedLanguageTag == languageCode {
                currentItem.select(option, in: group)
            }
        }
    }

    func selectSubtitleTrack(_ languageCode: String) {
        guard let currentItem = player?.currentItem,
              let group = currentItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
            return
        }

        for option in group.options {
            if option.extendedLanguageTag == languageCode {
                currentItem.select(option, in: group)
            }
        }
    }
}
