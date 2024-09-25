//
//  DeviceDataManager.swift
//  LiveTV
//
//  Created by CodingGuru on 9/24/24.
//

import Foundation

class DeviceDataManager {
    private let key = "HDHomeRunDevices"
    
    private let selectedKey = "selectedDevice"
    
    // Save devices to UserDefaults
    func saveDevices(_ devices: [Device]) {
        if let encoded = try? JSONEncoder().encode(devices) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    
    // Load devices from UserDefaults
    func loadDevices() -> [Device] {
        if let savedDevices = UserDefaults.standard.object(forKey: key) as? Data {
            if let loadedDevices = try? JSONDecoder().decode([Device].self, from: savedDevices) {
                return loadedDevices
            }
        }
        return []
    }
    
    // Save selected device to UserDefaults
    func setSelectedDevice(_ device: Device) {
        if let encoded = try? JSONEncoder().encode(device) {
            UserDefaults.standard.set(encoded, forKey: selectedKey)
        }
    }
    
    // Load selected device from UserDefaults
    func loadSelectedDevice() -> Device? {
        if let savedDevice = UserDefaults.standard.object(forKey: selectedKey) as? Data {
            if let loadedDevice = try? JSONDecoder().decode(Device.self, from: savedDevice) {
                return loadedDevice
            }
        }
        return nil
    }
}
