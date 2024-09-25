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
    @Published var deviceList: [Device] = []
    @Published var showAlert: Bool = false
    @Published var isLoading: Bool = true
    
    @Published var device: Device?
    
    private var dataManager = DeviceDataManager()
        
    init() {
        deviceList = dataManager.loadDevices()
    }
    
    func discoverDevices() {
        deviceList = []
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
                                let newDevice = Device(ip: "http://\(ip)/", name: decodedDevice.DeviceID, active: false)
                                self.deviceList.append(newDevice)
                            }
                        }
                    }
                    
                }.resume()
            }
            
        } else {
            print("No devices found or an error occurred")
        }
        self.isLoading = false
//        if self.devices.isEmpty {
//            self.showAlert = true
//        }
        
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
//        if self.channels.isEmpty {
//            self.showAlert = true
//        }
    }
    
    
    func loadDevicedata() {
//        var devices = [HDHomeRunDevice]()
        deviceList = []
        if let url = Bundle.main.url(forResource: "device", withExtension: "json") {
            do {
                // load data from the json file
                let data = try Data(contentsOf: url)
                // decode the json data
                let decoder = JSONDecoder()
                let deviceData = try decoder.decode([HDHomeRunDevice].self, from: data)
                
                self.devices = deviceData
                for device in deviceData.prefix(deviceData.count) {
                    let newDevice = Device(ip: device.BaseURL, name: device.DeviceID, active: false)
                    self.deviceList.append(newDevice)
                }
                
                
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
    
    // Manually add a device by its IP address
    func addDevice(ip: String, name: String) {
        if deviceList.contains(where: { $0.ip == ip }) {
            return
        }
        let newDevice = Device(ip: ip, name: name, active: false)
        deviceList.append(newDevice)
        saveDevices()  // Save the updated devices to storage
    }
    
    // Remove a device
    func removeDevice(at indexSet: IndexSet) {
        deviceList.remove(atOffsets: indexSet)
        saveDevices()  // Save the updated devices to storage
    }

    // Enforce that only one device can be enabled at a time
    func toggleDevice(_ device: Device) {
        if let index = deviceList.firstIndex(where: { $0.id == device.id }) {
            // If the device is being enabled, disable all other devices
            if !device.active! {
                // Disable all other devices
                for i in 0..<deviceList.count {
                    deviceList[i].active! = false
                }
                // Enable the selected device
                deviceList[index].active! = true
            } else {
                // If the device is being disabled, just disable it
                deviceList[index].active! = false
            }
            saveDevices()  // Save the updated devices to storage
            dataManager.setSelectedDevice(deviceList[index])
        }
    }
    
    
    // Save the current list of devices to UserDefaults
    private func saveDevices() {
        dataManager.saveDevices(deviceList)
        
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

// Devices
struct Device: Codable, Identifiable {
    let id = UUID()
    let ip: String
    let name: String
    var active: Bool?
    
    init(ip: String, name: String, active: Bool = false) {
        self.ip = ip
        self.name = name
        self.active = active
    }
}

