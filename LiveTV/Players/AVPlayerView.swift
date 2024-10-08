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

class AVPlayerController: UIViewController, ObservableObject, AVPlayerItemLegibleOutputPushDelegate {
    @ObservedObject var serverManager = ServerManager.shared
    var player: AVPlayer?
    var playerViewController: AVPlayerViewController!
    var statusLabel: UILabel = UILabel()  // Label for playback status feedback
    
    var isLoading = true
    var cancellables = Set<AnyCancellable>()
    var loadingTimer: AnyCancellable?
    var streamURL: URL
    var progressView: UIActivityIndicatorView?
    
//    var webServer: GCDWebServer!
    let playlistName = "master.m3u8"
    let videolistName = "video_stream.m3u8"
    let audiolistName = "audio_stream.m3u8"
    private var ffmpegSession: FFmpegSession?
    
    @Published var audioOptions: [AVMediaSelectionOption] = []
    @Published var subtitleOptions: [AVMediaSelectionOption] = []
    
    @Published var selectedAudioOption: AVMediaSelectionOption? = nil
    @Published var selectedSubtitleOption: AVMediaSelectionOption? = nil
    
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
//        startLocalHTTPServer()
        setupUI()
        checkAvailableStorage()
        DispatchQueue.main.asyncAfter(deadline: .now(), execute: waitForPlaylist)
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
//    func startLocalHTTPServer() {
//        // Initialize the web server
//        webServer = GCDWebServer()
//
//        webServer.addGETHandler(forBasePath: "/", directoryPath: getDocumentsDirectory().path, indexFilename: nil, cacheAge: 3600, allowRangeRequests: true)
//
//        webServer.start(withPort: 9090, bonjourName: "Local WebServer")
//        
//        print("Local server started at: \(webServer.serverURL?.absoluteString ?? "")")
//    }
//    
//    func stopWebServer() {
//        webServer?.stop()
//        webServer = nil
//    }
    
    //MARK: - Process the stream using FFmpeg
    func processStream() {
        let inputUrlString = streamURL.absoluteString

        guard let outputDirectory = createHLSOutputDirectory() else {
            print("Failed to create output directory")
            return
        }

        
        // FFmpeg command to create HLS
        let videoOutputPath = outputDirectory.appendingPathComponent(videolistName).path
        let audioOutputPath = outputDirectory.appendingPathComponent(audiolistName).path
        let masterPlaylistPath = outputDirectory.appendingPathComponent(playlistName).path
        
        createMasterPlaylist(masterPlaylistPath: masterPlaylistPath)


        let ffmpegCommand = """
            -i "\(inputUrlString)" \
            -map 0:0 -c:v h264_videotoolbox -vf yadif -crf 0 -b:v 9000k \
            -f hls -hls_time 1 -hls_list_size 0 -hls_flags delete_segments \
            -hls_segment_filename "\(outputDirectory.appendingPathComponent("segment_%03d.ts").path)" "\(videoOutputPath)" \
            -map 0:1 -c:a aac -b:a 128k -ac 2 \
            -f hls -hls_time 1 -hls_list_size 0 -hls_flags delete_segments \
            -hls_segment_filename "\(outputDirectory.appendingPathComponent("audio_segment_%03d.aac").path)" "\(audioOutputPath)"
        """

        // Set log level to AV_LOG_VERBOSE
        FFmpegKitConfig.setLogLevel(48)  // 32 is the value for AV_LOG_VERBOSE
        //        0 = AV_LOG_QUIET
        //        8 = AV_LOG_PANIC
        //        16 = AV_LOG_FATAL
        //        24 = AV_LOG_ERROR
        //        32 = AV_LOG_VERBOSE
        //        48 = AV_LOG_DEBUG
        //        56 = AV_LOG_TRACE
                
        // Enable log callback to capture and print FFmpeg logs
        FFmpegKitConfig.enableLogCallback { log in
            if let logMessage = log?.getMessage() {
                print("FFmpegLOG: \(logMessage)")
            }
        }
        

        // Execute the FFmpeg command
        self.ffmpegSession = FFmpegKit.executeAsync(ffmpegCommand) { [weak self] session in
            guard let self = self else { return }
            let returnCode = session?.getReturnCode()
            
//            // Log the FFmpeg output
//            session?.getLogs()?.forEach { log in
//                print((log as AnyObject).getMessage() as Any)
//            }
            
            // Safely unwrap and log FFmpeg output
            if let logs = session?.getLogs() {
                for log in logs {
                    if let logMessage = (log as? Log)?.getMessage() {
                        print("FFmpeg Log: \(logMessage)")
                    }
                }
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
    
    // This creates the master playlist (playlist.m3u8) before starting FFmpeg process
    func createMasterPlaylist(masterPlaylistPath: String) {
        let masterPlaylistContent = """
        #EXTM3U
        #EXT-X-VERSION:3

        # Declare the audio streams
        #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",LANGUAGE="en",NAME="English Stereo",AUTOSELECT=YES,DEFAULT=YES,URI="audio_stream.m3u8"


        # Video stream that includes the audio and subtitle tracks
        #EXT-X-STREAM-INF:BANDWIDTH=5000000,AUDIO="audio"
        video_stream.m3u8
        """

        // Write the master playlist to file
        do {
            try masterPlaylistContent.write(toFile: masterPlaylistPath, atomically: true, encoding: .utf8)
            print("Master playlist created at: \(masterPlaylistPath)")
        } catch {
            print("Failed to create master playlist: \(error)")
        }
    }
    
    

    //MARK: - AVPlayer setup
    // Wait for the playlist to become available and play
    func waitForPlaylist() {
        guard let outputDirectory = createHLSOutputDirectory() else {
            print("Failed to create output directory")
            return
        }
        let outputURL = outputDirectory.appendingPathComponent(videolistName)
        
        loadingTimer = Timer.publish(every: 0.1, on: .main, in: .common) 
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
        guard let serverURL = serverManager.streamURL else {
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

        playerViewController = AVPlayerViewController()
        playerViewController.player = player
        playerViewController.showsPlaybackControls = true  // Enable default playback controls

        // Add AVPlayerViewController as a child view controller
        
        if let playerViewController = playerViewController {
            addChild(playerViewController)
            playerViewController.view.frame = self.view.bounds
            self.view.addSubview(playerViewController.view)
            playerViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

            playerViewController.didMove(toParent: self)
        }

        updateStatusLabel(with: "Playing...")
        // Start playback
        player?.play()
        progressView?.stopAnimating()
        isLoading = false
        
        addExternalSubtitle(url: getDocumentsDirectory().appendingPathComponent("HLSOutput/segment_000.vtt"))
        
        // Observer for player's status, e.g., ready to play
        player?.addObserver(self, forKeyPath: "status", options: [.new, .initial], context: nil)
        
        // Setup audio and subtitle track selection
        setupMediaSelection()
   }
    
    
    func addExternalSubtitle(url: URL) {
        guard let playerItem = player?.currentItem else { return }
        
        let subtitleAsset = AVURLAsset(url: url)
        let subtitleItem = AVPlayerItem(asset: subtitleAsset)
        
        let legibleOutput = AVPlayerItemLegibleOutput()
        legibleOutput.setDelegate(self, queue: DispatchQueue.main)
        playerItem.add(legibleOutput)
        
        print("Subtitle added: \(url.absoluteString)")
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
//        self.stopWebServer()
        player?.pause()
        player?.removeObserver(self, forKeyPath: "status")
        player = nil
        self.ffmpegSession?.cancel()
        self.ffmpegSession = nil
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
    
    // Set up available media tracks (audio and subtitles)
    func setupMediaSelection() {
        guard let currentItem = player?.currentItem else { return }

        // Get available audio tracks
        if let audioGroup = currentItem.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) {
            audioOptions = audioGroup.options
            selectedAudioOption = currentItem.selectedMediaOption(in: audioGroup)
        }

        // Get available subtitle tracks
        if let subtitleGroup = currentItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
            subtitleOptions = subtitleGroup.options
            selectedSubtitleOption = currentItem.selectedMediaOption(in: subtitleGroup)
        }
    }

    // Select the chosen audio or subtitle track
    func selectAudioTrack(_ option: AVMediaSelectionOption) {
        guard let currentItem = player?.currentItem else { return }
        if let audioGroup = currentItem.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) {
            currentItem.select(option, in: audioGroup)
            print("Selected audio track: \(option.displayName)")
        }
    }

    func selectSubtitleTrack(_ option: AVMediaSelectionOption) {
        guard let currentItem = player?.currentItem else { return }
        if let subtitleGroup = currentItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
            currentItem.select(option, in: subtitleGroup)
            print("Selected subtitle track: \(option.displayName)")
        }
    }
}
