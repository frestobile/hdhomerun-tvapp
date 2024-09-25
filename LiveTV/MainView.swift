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
                    ProgressView("Loading an Active Device")
                } else {
                    List {
                        NavigationLink(
                            destination: LiveView(lineupUrl: model.selectedDevice == nil ? "http://192.168.8.173" : model.selectedDevice!.ip),
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
                model.getActiveDevice()
            }
            .alert(isPresented: $model.showAlert) {
                Alert(
                    title: Text("No Active HDHomeRun Devices Found"),
                    message: Text("We couldn't find Activated HDHomeRun device on your network. Please Active a device in Settings"),
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

