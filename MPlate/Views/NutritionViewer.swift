//
//  NutritionViewer.swift
//  MPlate
//

import SwiftUI

struct NutritionViewer: SwiftUI.View {
    @State var name: String
    @State var kcal: String
    @State var pro: String
    @State var fat: String
    @State var cho: String
    @State var serving: String

    var body: some SwiftUI.View {
        NavigationStack {
            VStack {
                Text(name).bold()
                    .font(.largeTitle)
                    .padding(12)

                Divider()

                VStack {
                    HStack {
                        Text("Serving: " + serving)
                        Spacer()
                    }
                    HStack {
                        Text("Calories: " + kcal)
                        Spacer()
                    }
                    HStack {
                        Text("Protein: " + pro)
                        Spacer()
                    }
                    HStack {
                        Text("Fat: " + fat)
                        Spacer()
                    }
                    HStack {
                        Text("Carbs: " + cho)
                        Spacer()
                    }
                }
                .font(.title2)
                .padding(.leading, 15)
                .foregroundStyle(Color.mBlue)

                Spacer()

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
                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
