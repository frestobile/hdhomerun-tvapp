import SwiftUI

class SharedData: ObservableObject {
    @Published var message: String = "Hello from SharedData"
}

struct MainView: View {
    @State private var selectedMenu: Menu? = nil
    @State private var selectedSettingsMenu: SettingsMenu? = nil
    @StateObject private var model = HDHomeRunModel()

    var body: some View {
        NavigationView {
            VStack {
                if model.isLoading {
                    ProgressView("Fetching Devices...")
                } else if model.devices.isEmpty {
                    Text("No Devices Available")
                } else {
                    List {
                        NavigationLink(
                            destination: LiveView(lineupUrl: model.devices[0].LineupURL),
                            tag: Menu.liveTV,
                            selection: $selectedMenu
                        ) {
                            Text("Live TV")
                        }
                        
                        NavigationLink(
                            destination: SettingsView(),
                            tag: Menu.settings,
                            selection: $selectedMenu
                        ) {
                            Text("Settings")
                        }
                    }
                }
            }
            .onAppear {
//                model.discoverDevices()
                model.loadDevicedata()
            }
            .alert(isPresented: $model.showAlert) {
                Alert(
                    title: Text("No HDHomeRun Devices Found"),
                    message: Text("We couldn't find any HDHomeRun devices on your network. Please check your device and network."),
                    dismissButton: .default(Text("OK"))
                
                )
            }
            .navigationTitle("Main Menu")
        }
    }
}

enum Menu: Hashable {
    case liveTV
    case settings
}


struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}



//struct SettingsView_Previews: PreviewProvider {
//    @State static var selectedSettingsMenu: SettingsMenu? = nil
//    
//    static var previews: some View {
//        SettingsView(selectedSettingsMenu: $selectedSettingsMenu)
//    }
//}

