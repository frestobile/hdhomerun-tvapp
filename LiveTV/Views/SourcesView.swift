//
//  SourcesView.swift
//  LiveTV
//
//  Created by CodingGuru on 9/7/24.
//

import SwiftUI

struct SourcesView: View {
    @StateObject private var model = HDHomeRunModel()
    @State private var manualIP: String = ""
    @State private var manualDeviceName: String = ""
    @State private var selectedDeviceId: UUID? = nil
    
    var body: some View {
        NavigationView {
            VStack {
                if model.isLoading {
                    ProgressView("Fetching Devices...")
                } else if model.deviceList.isEmpty {
                    Text("No Device Available")
                } else {
                    // Sources Section: Listing discovered or manually added devices
                    List {
                        
                        ForEach(model.deviceList.indices, id: \.self) { index in
                            let device = model.deviceList[index]

                            HStack {
                                VStack(alignment: .leading) {
                                    // Change the text color based on selection
                                    Text(device.name)
                                        .foregroundColor(.blue )
                                    Text(device.ip)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                // Toggle for active/inactive state
                                Toggle(isOn: Binding<Bool>(
                                    get: { model.deviceList[index].active ?? false }, // Get the current value
                                    set: { newValue in
                                        // model.deviceList[index].active = newValue  // Set the new value
                                        model.toggleDevice(model.deviceList[index])
                                    }
                                )) {
                                    Text(device.active ?? false ? "Active" : "Inactive")
                                        .font(.subheadline)
                                        .foregroundColor(device.active ?? false ? .green : .red)
                                }
                            }
                            .contentShape(Rectangle())

                        }
                        .onDelete(perform: model.removeDevice)
                    }
                }
                
                // Add Device Manually Section
                HStack {
                    TextField("Enter Device Name", text: $manualIP)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Enter Device IP", text: $manualDeviceName)
                        .keyboardType(.numbersAndPunctuation)
                    var ipAddress = "http://\(manualIP)/"
                    Button("Add Device") {
                        model.addDevice(ip: ipAddress, name: manualDeviceName)
                        manualIP = ""  // Clear input after adding
                        ipAddress = ""
                    }
                    .padding(.leading, 10)
                }
                .padding()

                Spacer()

                // Discover Devices Button
                Button("Discover Devices") {
                    model.discoverDevices()
//                    model.loadDevicedata()
                }
                .padding()
            }
            .onAppear {
                model.discoverDevices()
//                model.loadDevicedata()

            }
            .navigationTitle("HDHomeRun Sources")
        }
    
    }
}

#Preview {
    SourcesView()
}
