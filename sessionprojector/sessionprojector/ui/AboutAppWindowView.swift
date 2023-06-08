//
//  AboutUlalacaWindowView.swift
//  sessionprojector
//
//  Created by Gyuhwan Park on 2023/02/02.
//

import SwiftUI

import UlalacaCore

struct AboutAppWindowView: View {
    
    @Environment(\.openURL)
    var openURL
    
    var body: some View {
        VStack {
            HStack(alignment: .center) {
                Image("Logo")
                    .resizable()
                    .frame(width: 128.0, height: 128.0)
                    .help("君の夢はうららかに")
                VStack {
                    HStack(alignment: .center) {
                        Text("麗")
                            .font(.system(size: 48, weight: .light, design: .default))
                            .onTapGesture {
                                guard let url = URL(string: "https://en.wiktionary.org/wiki/%E9%BA%97#Japanese") else { return }
                                openURL(url)
                            }
                        Text("\\~Ulalaca\\~")
                            .font(.system(size: 36, weight: .ultraLight, design: .default))
                    }
                    VStack(alignment: .center) {
                        Text("sessionprojector.app")
                            .bold()
                        Text("Version \(UlalacaVersion())")
                    }
                }
            }
            
            
            VStack {
                Text("This software is licensed under [Apache License 2.0](https://github.com/team-unstablers/ulalaca/blob/main/LICENSE).")
                
            }
            .padding(EdgeInsets(top: 16.0, leading: 0, bottom: 16.0, trailing: 0))
            
            VStack {
                Text("©︎2022-2023 team unstablers Inc.")
                    // TODO: + "and ulalaca contributors"
                    .multilineTextAlignment(.center)
                Text("https://unstabler.pl")
            }
        }
        .padding(16.0)
        .frame(width: 400)
    }
}


struct AboutAppWindowView_Previews: PreviewProvider {
    static var previews: some View {
        AboutAppWindowView()
    }
}
