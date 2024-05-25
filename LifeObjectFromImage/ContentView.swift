//
//  ContentView.swift
//  LifeObjectFromImage
//
//  Created by Msz on 2024/05/25.
//

import SwiftUI

struct ContentView: View {
    
    var body: some View {
        
        NavigationStack {
            List {
                
                Text("Please test this on a physical device. Simulators are not supported.")
                
                NavigationLink("System provided pickable UIImageView") {
                    ObjectExtraction()
                }
                
            }
        }
        
    }
    
}

#Preview {
    ContentView()
}
