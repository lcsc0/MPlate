//
//  InfoView.swift
//  MPlate
//

import SwiftUI

struct Info: SwiftUI.View {
    var body: some SwiftUI.View {
        NavigationStack {
            HStack {
                Text("Maize")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.mmaize)
                Text("Plate")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.mBlue)
            }
            .padding(.top, 50.0)
            Spacer()
            Text("MaizePlate is an application created using the \nU-M Dining API to provide a way to easily and more accurately track calories & macros from foods eaten in U-M dining halls.\n\nYou must be connected to the U-M WiFi for the app to function properly.\n\nMaizePlate is not an official U-M application and is not affiliated with U-M in any way.\n\nDisclaimer: The calorie and nutrition information provided by this app is intended for general informational purposes only, and is not intended for use in managing medical conditions or making health decisions. \n")
                .padding(.bottom, 50.0)
                .padding(.horizontal, 25.0)
            Spacer()
            NavigationLink(destination: VStack {
                Text("MaizePlate does not share any data with third-parties. Foods and nutrients that you've tracked are all stored locally on your device and will be erased if the app is deleted. Approximate location and app usage data are tracked for analytics purposes. These analytics will stop being tracked if the app is deleted, and are never shared with any third-parties.").padding()
                Spacer()
            }.navigationTitle("Privacy Policy")) {
                Text("Privacy Policy")
                    .padding()
            }
            Spacer()
        }
    }
}
