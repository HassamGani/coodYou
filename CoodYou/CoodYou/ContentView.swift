//
//  ContentView.swift
//  CoodYou
//
//  Created by Hassam Gani on 27/09/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            VStack {
                Text("Home")
                    .font(.largeTitle)
                    .padding()
                Text("CampusDash — Home placeholder")
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }

            VStack {
                Text("Dasher")
                    .font(.largeTitle)
                    .padding()
                Text("Assignments and claims")
            }
            .tabItem {
                Label("Dasher", systemImage: "bicycle")
            }

            VStack {
                Text("Wallet")
                    .font(.largeTitle)
                    .padding()
                Text("Earnings and payouts")
            }
            .tabItem {
                Label("Wallet", systemImage: "wallet.pass")
            }

            VStack {
                Text("Profile")
                    .font(.largeTitle)
                    .padding()
                Text("User profile and settings")
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
