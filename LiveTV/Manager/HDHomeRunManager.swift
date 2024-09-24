//
//  HDHomeRunManager.swift
//  LiveTV
//
//  Created by CodingGuru on 9/10/24.
//

import Foundation
import Combine

class HDHomeRunManager: ObservableObject {
    var hdHomerunDevice: HDHomeRunDevice?
    
    private var cancellable: AnyCancellable?
    
    func discoverDevices() -> [HDHomeRunDevice]? {
        hdhomerun_debug_enable(nil)
        var deviceArr = [HDHomeRunDevice]()
        var devices = [hdhomerun_discover_device_t](repeating: hdhomerun_discover_device_t(), count: 10)
        let devicePointer = UnsafeMutablePointer(&devices)

        let numDevices = hdhomerun_discover_find_devices_custom_v2(0, UInt32(HDHOMERUN_DEVICE_TYPE_TUNER), UInt32(HDHOMERUN_DEVICE_ID_WILDCARD), devicePointer, Int32(UInt32(devices.count)))

        if numDevices >= 0  {
            for device in devices.prefix(Int(numDevices)) {
                let deviceID = String(format: "%08X", device.device_id) // Format as 8-digit hex
                let ip = formatIPAddress(device.ip_addr) // Format IP Address
                print("IP Address: \(ip)")
                guard let url = URL(string: "http://\(ip)/discover.json") else { return nil }
                URLSession.shared.dataTask(with: url) { data, response, error in
                    if let data = data {
                        let decoder = JSONDecoder()
                        if let decodedDevice = try? decoder.decode(HDHomeRunDevice.self, from: data) {
                            DispatchQueue.main.async {
                                deviceArr.append(decodedDevice)
                            }
                        }
                    }
                }.resume()
                
            }
        } else {
            print("No devices found or an error occurred")
            return nil
        }
        return deviceArr
    }
    
    // Function to format the IP address
    func formatIPAddress(_ ipAddr: UInt32) -> String {
        let octet1 = (ipAddr >> 24) & 0xFF
        let octet2 = (ipAddr >> 16) & 0xFF
        let octet3 = (ipAddr >> 8) & 0xFF
        let octet4 = ipAddr & 0xFF
        return "\(octet1).\(octet2).\(octet3).\(octet4)"
    }

    func getChannelList(lineupUrl: String) -> [HDHomeRunChannel] {
        var channels: [HDHomeRunChannel] = []
        let url = URL(string: lineupUrl)!
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                let decoder = JSONDecoder()
                if let decodedChannels = try? decoder.decode([HDHomeRunChannel].self, from: data) {
                    DispatchQueue.main.async {
                        channels = decodedChannels
                    }
                }
            }
        }.resume()
        return channels
    }
    
    
    func loadDevicedata() -> [HDHomeRunDevice]? {
//        var devices = [HDHomeRunDevice]()
        if let url = Bundle.main.url(forResource: "device", withExtension: "json") {
            do {
                // load data from the json file
                let data = try? Data(contentsOf: url)
                // decode the json data
                let decoder = JSONDecoder()
                let deviceData = try? decoder.decode([HDHomeRunDevice].self, from: data!)
                
                return deviceData!
            } catch {
                print("Error loading or decoding JSON file: \(error)")
                return nil
            }
        } else {
            print("Json file not found")
            return nil
        }
    }
    
    func loadChanneldata() -> [HDHomeRunChannel]? {
//        var devices = [HDHomeRunDevice]()
        if let url = Bundle.main.url(forResource: "channels", withExtension: "json") {
            do {
                // load data from the json file
                let data = try? Data(contentsOf: url)
                // decode the json data
                let decoder = JSONDecoder()
                let channelsData = try? decoder.decode([HDHomeRunChannel].self, from: data!)
                
                return channelsData!
            } catch {
                print("Error loading or decoding JSON file: \(error)")
                return nil
            }
        } else {
            print("Json file not found")
            return nil
        }
    }
}


