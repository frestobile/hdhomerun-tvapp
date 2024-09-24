//
//  DeviceModel.swift
//  LiveTV
//
//  Created by CodingGuru on 9/10/24.
//

import Foundation
import SwiftUI

class HDHomeRunModel: ObservableObject {
    @Published var devices: [HDHomeRunDevice] = []
    @Published var channels: [HDHomeRunChannel] = []
    @Published var showAlert: Bool = false
    @Published var isLoading: Bool = true
        
//    init(devices: [HDHomeRunDevice], channels: [HDHomeRunChannel], showAlert: Bool) {
//        self.devices = devices
//        self.channels = channels
//        self.showAlert = showAlert
//    }
    
    func descoverDevices() {
        hdhomerun_debug_enable(nil)
        var devices = [hdhomerun_discover_device_t](repeating: hdhomerun_discover_device_t(), count: 10)
        let devicePointer = UnsafeMutablePointer(&devices)

        let numDevices = hdhomerun_discover_find_devices_custom_v2(0, UInt32(HDHOMERUN_DEVICE_TYPE_TUNER), UInt32(HDHOMERUN_DEVICE_ID_WILDCARD), devicePointer, Int32(UInt32(devices.count)))

        if numDevices >= 0  {
            for device in devices.prefix(Int(numDevices)) {
                let deviceID = String(format: "%08X", device.device_id) // Format as 8-digit hex
                let ip = formatIPAddress(device.ip_addr) // Format IP Address
                print("IP Address: \(ip)")
                guard let url = URL(string: "http://\(ip)/discover.json") else { return}
                URLSession.shared.dataTask(with: url) { data, response, error in
                    if let data = data {
                        let decoder = JSONDecoder()
                        if let decodedDevice = try? decoder.decode(HDHomeRunDevice.self, from: data) {
                            DispatchQueue.main.async {
                                self.devices.append(decodedDevice)
                            }
                        }
                    }
                    
                }.resume()
            }
            
        } else {
            print("No devices found or an error occurred")
        }
        self.isLoading = false
        if self.devices.isEmpty {
            self.showAlert = true
        }
        
    }
    
    func getChannelList(lineupUrl: String) {
        
        let url = URL(string: lineupUrl)!
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                let decoder = JSONDecoder()
                if let decodedChannels = try? decoder.decode([HDHomeRunChannel].self, from: data) {
                    DispatchQueue.main.async {
                        self.channels = decodedChannels
                    }
                }
            }
        }.resume()
        self.isLoading = false
        if self.channels.isEmpty {
            self.showAlert = true
        }
    }
    
    
    func loadDevicedata() {
//        var devices = [HDHomeRunDevice]()
        if let url = Bundle.main.url(forResource: "device", withExtension: "json") {
            do {
                // load data from the json file
                let data = try Data(contentsOf: url)
                // decode the json data
                let decoder = JSONDecoder()
                let deviceData = try decoder.decode([HDHomeRunDevice].self, from: data)
                
                self.devices = deviceData
                
            } catch {
                print("Error loading or decoding JSON file: \(error)")
                
            }
        } else {
            print("Json file not found")
        }
        self.isLoading = false
        if self.devices.isEmpty {
            self.showAlert = true
        }
    }
    
    func loadChanneldata() {
//        var devices = [HDHomeRunDevice]()
        if let url = Bundle.main.url(forResource: "channels", withExtension: "json") {
            do {
                // load data from the json file
                let data = try Data(contentsOf: url)
                // decode the json data
                let decoder = JSONDecoder()
                let channelsData = try decoder.decode([HDHomeRunChannel].self, from: data)
                
                self.channels = channelsData
            } catch {
                print("Error loading or decoding JSON file: \(error)")
            }
        } else {
            print("Json file not found")
        }
        self.isLoading = false
        if self.channels.isEmpty {
            self.showAlert = true
        }
    }
    
    // Function to format the IP address
    func formatIPAddress(_ ipAddr: UInt32) -> String {
        let octet1 = (ipAddr >> 24) & 0xFF
        let octet2 = (ipAddr >> 16) & 0xFF
        let octet3 = (ipAddr >> 8) & 0xFF
        let octet4 = ipAddr & 0xFF
        return "\(octet1).\(octet2).\(octet3).\(octet4)"
    }
    
}

//  Device
struct HDHomeRunDevice: Codable {
    let FriendlyName: String
    let ModelNumber: String
    let FirmwareName: String
    let FirmwareVersion: String
    let DeviceID: String
    let DeviceAuth: String
    let BaseURL: String
    let LineupURL: String
    let TunerCount: Int
}

// Channel
struct HDHomeRunChannel: Codable {
    let GuideNumber: String
    let GuideName: String
    let VideoCodec: String
    let AudioCodec: String
    let HD: Int?
    let Favorite: Int?
    let URL: String
}

