//
//  PreferencesWindowView.swift
//  sessionprojector
//
//  Created by Gyuhwan Park on 2023/01/25.
//

import SwiftUI

struct ConnectionRow: View {
    var connection: ProjectionSession
    
    var body: some View {
        VStack() {
            Text("\(connection.clientInfo.clientAddress)")
                .bold()
            Text("\(connection.clientInfo.program); ulalaca \(connection.clientInfo.xrdpUlalacaVersion)")
        }
    }
}

struct PreferencesWindowView: View {
    @EnvironmentObject
    var appState: AppState
    
    var body: some View {
        VStack {
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    GroupBox(label: Text("Global (not implemented yet)")) {
                        VStack(alignment: .leading) {
                            Toggle("Launch sessionprojector on loginwindow", isOn: $appState.globalPreferences.launchOnLoginwindow)
                                .disabled(true)
                            Toggle("Launch sessionprojector on user login", isOn: $appState.globalPreferences.launchOnUserLogin)
                                .disabled(true)
                        }.frame(maxWidth: .infinity)
                    }
                    GroupBox(label: Text("Per-user")) {
                        VStack(alignment: .leading) {
                            
                            VStack(alignment: .leading) {
                                Text("Preferred Screen Recorder")
                                Picker("", selection: $appState.userPreferences.primaryScreenRecorder) {
                                    ForEach(ScreenRecorderType.allCases) { type in
                                        Text(type.description).tag(type)
                                    }
                                }
                                Text("- AVFScreenRecorder will be used when screen is locked")
                                    .font(.system(size: 9.0))
                            }
                        }.frame(maxWidth: .infinity)
                    }


                }
                .frame(maxWidth: .infinity)
                VStack {
                    GroupBox(label: Text("SCScreenRecorder Preferences")) {
                        VStack(alignment: .leading) {
                            VStack {
                                Toggle("Set Update Interval Automatically", isOn: $appState.userPreferences.autoFramerate)
                            }
                            VStack {
                                Text("Update Interval: 1 / \(Int(appState.userPreferences.framerate))")
                                    .disabled(appState.userPreferences.autoFramerate)
                                Slider(
                                    value: $appState.userPreferences.framerate,
                                    in: 15...60,
                                    step: 5
                                ) {
                                    
                                } minimumValueLabel: {
                                    Text("15")
                                } maximumValueLabel: {
                                    Text("60")
                                }
                                .disabled(appState.userPreferences.autoFramerate)
                            }
                        }
                    }
                    GroupBox(label: Text("AVFScreenRecorder Preferences")) {
                        Text("(Not Available)")
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            /*
            HStack {
                GroupBox(label: Text("Diagnostics")) {
                    VStack(alignment: .leading) {
                        Toggle("xrdp is running (version ...)", isOn: $appState.globalPreferences.launchOnLoginwindow)
                            .disabled(true)
                        Toggle("sessionbroker is running (version ...)", isOn: $appState.globalPreferences.launchOnUserLogin)
                            .disabled(true)
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
             */
            HStack {
                GroupBox(label: Text("Current Sessions")) {
                    List(Array(appState.connections)) { connection in
                        ConnectionRow(connection: connection)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            HStack {
                Button("Save") {
                    appState.savePreferences()
                }
                Button("Close") {
                    appState.hidePreferencesWindow()
                }
            }
        }.padding(16)
    }
}

struct PreferencesWindowView_Previews: PreviewProvider {
    static let appState = AppState()
    
    static var previews: some View {
        PreferencesWindowView()
            .environmentObject(appState)
    }
}
