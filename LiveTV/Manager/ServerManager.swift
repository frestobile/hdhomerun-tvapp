//
//  VideoPlayer.swift
//  LiveTV
//
//  Created by CodingGuru on 9/16/24.
//
import Combine
import Foundation
import ffmpegkit
import GCDWebServer

class ServerManager: ObservableObject {
    static let shared = ServerManager()  // Singleton instance

    @Published var isServerRunning = false
    @Published var streamURL: URL? = nil

    private var webServer = GCDWebServer()
    let playlistName = "master.m3u8"
    let videolistName = "video_stream.m3u8"
    let audiolistName = "audio_stream.m3u8"
    
    private var ffmpegSession: FFmpegSession?
    var isLoading = true
    var cancellables = Set<AnyCancellable>()
    var loadingTimer: AnyCancellable?

    private init() {}  // Prevent external instantiation

    // Start the web server
    func startWebServer() {
        webServer.addGETHandler(forBasePath: "/", directoryPath: getDocumentsDirectory().path, indexFilename: nil, cacheAge: 3600, allowRangeRequests: true)

        do {
            try webServer.start(options: [
                GCDWebServerOption_Port: 9090,
                GCDWebServerOption_BindToLocalhost: true
            ])
            print("Web server started on port \(webServer.serverURL!)")
            
            if webServer.isRunning {
//                self.streamURL = webServer.serverURL?.appendingPathComponent("playlist.m3u8")
                self.isServerRunning = true
            }
        } catch {
            print("Error starting web server: \(error)")
            self.isServerRunning = false
        }
    }

    // Stop the web server
    func stopWebServer() {
        if webServer.isRunning {
            webServer.stop()
            self.isServerRunning = false
            print("Web server stopped")
        }
    }
    
    func getDocumentsDirectory() -> URL {
        return FileManager.default.temporaryDirectory
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
    
    //MARK: - Process the stream using FFmpeg
    func processStream(streamURL: URL) {
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
        guard let serverURL = webServer.serverURL else {
            print("Web server is not running.")
            return
        }
        let hlsURL = serverURL.appendingPathComponent("HLSOutput/\(playlistName)")
        print("Stream URL: \(hlsURL.absoluteString)")
        
        self.streamURL = hlsURL
        self.isLoading = false
        
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
}
