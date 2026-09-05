import SwiftUI

@main
struct C920ControlApp: App {
    @StateObject private var model = CameraModel()

    var body: some Scene {
        MenuBarExtra("C920 Control", systemImage: "web.camera") {
            ContentView().environmentObject(model)
        }
        .menuBarExtraStyle(.window)
    }
}
