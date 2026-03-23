//
//  FoodPhotoView.swift
//  MPlate
//
//  Full SwiftUI view for photo-based food tracking.
//  Supports single-photo mode and before/after mode.
//  Uses AIService (Claude Vision) to identify items and estimate portions.
//

import SwiftUI
import UIKit

// MARK: - Enums

enum PhotoMode: String, CaseIterable {
    case single = "Single Photo"
    case beforeAfter = "Before & After"
}

enum CaptureTarget {
    case single
    case before
    case after
}

// MARK: - Main View

struct FoodPhotoView: View {
    let mealName: String

    @StateObject private var aiService = AIService()
    @Environment(\.dismiss) private var dismiss

    @State private var mode: PhotoMode = .single
    @State private var capturedImage: UIImage?
    @State private var beforeImage: UIImage?
    @State private var afterImage: UIImage?
    @State private var showCamera = false
    @State private var captureTarget: CaptureTarget = .single
    @State private var usePhotoLibrary = false
    @State private var savedSuccessfully = false
    @State private var saveError: String?

    // Mirror aiService state for local editing (isSelected toggles)
    @State private var selectableItems: [PhotoFoodItem] = []
    @State private var resultsLoaded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    modePicker
                    if mode == .single {
                        singleModeContent
                    } else {
                        beforeAfterModeContent
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 40)
            }
            .navigationTitle("Photo Food Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.mBlue)
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraView(
                    sourceType: usePhotoLibrary ? .photoLibrary : .camera
                ) { image in
                    handleCapture(image)
                }
            }
            .onChange(of: aiService.photoItems) { items in
                selectableItems = items
                resultsLoaded = !items.isEmpty
            }
        }
    }

    // MARK: - Mode Picker

    private var modePicker: some View {
        Picker("Mode", selection: $mode) {
            ForEach(PhotoMode.allCases, id: \.self) { m in
                Text(m.rawValue).tag(m)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: mode) { _ in
            resetState()
        }
    }

    // MARK: - Single Mode

    @ViewBuilder
    private var singleModeContent: some View {
        if savedSuccessfully {
            successView
        } else if aiService.isPhotoAnalyzing {
            analyzingView
        } else if resultsLoaded {
            resultsSection
            logButton
        } else if let img = capturedImage {
            imageThumbnail(img)
            analyzeControls(analyzeAction: {
                Task { await aiService.analyzeFoodPhoto(img) }
            }, retakeAction: {
                capturedImage = nil
                resultsLoaded = false
            })
        } else {
            cameraButtons(target: .single)
        }

        if let err = aiService.photoError {
            Text(err)
                .font(.caption)
                .foregroundStyle(Color.red)
                .multilineTextAlignment(.center)
        }
        if let err = saveError {
            Text(err)
                .font(.caption)
                .foregroundStyle(Color.red)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Before/After Mode

    @ViewBuilder
    private var beforeAfterModeContent: some View {
        if savedSuccessfully {
            successView
        } else if aiService.isPhotoAnalyzing {
            analyzingView
        } else if resultsLoaded {
            resultsSection
            logButton
        } else {
            beforeAfterSlots
            if beforeImage != nil && afterImage != nil {
                Button {
                    guard let b = beforeImage, let a = afterImage else { return }
                    Task { await aiService.analyzeBeforeAfterPhotos(before: b, after: a) }
                } label: {
                    Label("Analyze What I Ate", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.mBlue)
                        .cornerRadius(13)
                }
                .buttonStyle(.plain)
            }
        }

        if let err = aiService.photoError {
            Text(err)
                .font(.caption)
                .foregroundStyle(Color.red)
                .multilineTextAlignment(.center)
        }
        if let err = saveError {
            Text(err)
                .font(.caption)
                .foregroundStyle(Color.red)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Before/After Slots

    private var beforeAfterSlots: some View {
        HStack(spacing: 16) {
            photoSlot(
                label: "Before",
                image: beforeImage,
                target: .before
            )
            photoSlot(
                label: "After",
                image: afterImage,
                target: .after
            )
        }
    }

    @ViewBuilder
    private func photoSlot(label: String, image: UIImage?, target: CaptureTarget) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.headline)
                .foregroundStyle(Color.primary)

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .frame(height: 160)

                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.largeTitle)
                            .foregroundStyle(Color.mBlue)
                        Text("Tap to add")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
            .onTapGesture {
                captureTarget = target
                usePhotoLibrary = false
                showCamera = true
            }

            if image != nil {
                HStack(spacing: 8) {
                    Button("Retake") {
                        captureTarget = target
                        usePhotoLibrary = false
                        showCamera = true
                    }
                    .font(.caption)
                    .foregroundStyle(Color.mBlue)

                    Button("Library") {
                        captureTarget = target
                        usePhotoLibrary = true
                        showCamera = true
                    }
                    .font(.caption)
                    .foregroundStyle(Color.mBlue)
                }
            } else {
                Button("From Library") {
                    captureTarget = target
                    usePhotoLibrary = true
                    showCamera = true
                }
                .font(.caption)
                .foregroundStyle(Color.mBlue)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Camera Buttons (single mode)

    @ViewBuilder
    private func cameraButtons(target: CaptureTarget) -> some View {
        VStack(spacing: 16) {
            Button {
                captureTarget = target
                usePhotoLibrary = false
                showCamera = true
            } label: {
                Label("Take Photo", systemImage: "camera.fill")
                    .font(.headline)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.mBlue)
                    .cornerRadius(13)
            }
            .buttonStyle(.plain)

            Button {
                captureTarget = target
                usePhotoLibrary = true
                showCamera = true
            } label: {
                Label("Choose from Library", systemImage: "photo.on.rectangle")
                    .font(.subheadline)
                    .foregroundStyle(Color.mBlue)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Image Thumbnail

    private func imageThumbnail(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 13))
    }

    // MARK: - Analyze Controls

    @ViewBuilder
    private func analyzeControls(analyzeAction: @escaping () -> Void, retakeAction: @escaping () -> Void) -> some View {
        HStack(spacing: 16) {
            Button(action: retakeAction) {
                Text("Retake")
                    .font(.subheadline)
                    .foregroundStyle(Color.mBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray5))
                    .cornerRadius(13)
            }
            .buttonStyle(.plain)

            Button(action: analyzeAction) {
                Label("Analyze", systemImage: "sparkles")
                    .font(.subheadline)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.mBlue)
                    .cornerRadius(13)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Analyzing View

    private var analyzingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.4)
            Text("Analyzing your food...")
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Results Section

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !aiService.photoSummary.isEmpty {
                Text(aiService.photoSummary)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.leading)
            }

            Text("Select items to log:")
                .font(.caption)
                .foregroundStyle(Color.secondary)

            ForEach($selectableItems) { $item in
                HStack(alignment: .top, spacing: 12) {
                    Toggle("", isOn: $item.isSelected)
                        .labelsHidden()
                        .tint(Color.mBlue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(item.portionDescription)
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                        Text("\(item.calories) cal · \(item.protein)g pro · \(item.fat)g fat · \(item.carbs)g carbs")
                            .font(.caption2)
                            .foregroundStyle(Color.mBlue)
                    }
                    Spacer()
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
        }
    }

    // MARK: - Log Button

    private var logButton: some View {
        Button {
            logSelectedItems()
        } label: {
            Text("Log to \(mealName)")
                .font(.headline)
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(selectableItems.contains(where: { $0.isSelected }) ? Color.mBlue : Color.gray)
                .cornerRadius(13)
        }
        .buttonStyle(.plain)
        .disabled(!selectableItems.contains(where: { $0.isSelected }))
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.green)
            Text("Logged!")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Items added to \(mealName)")
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(Color.mBlue)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Helpers

    private func handleCapture(_ image: UIImage) {
        switch captureTarget {
        case .single:
            capturedImage = image
        case .before:
            beforeImage = image
        case .after:
            afterImage = image
        }
    }

    private func resetState() {
        capturedImage = nil
        beforeImage = nil
        afterImage = nil
        selectableItems = []
        resultsLoaded = false
        savedSuccessfully = false
        saveError = nil
        aiService.photoItems = []
        aiService.photoSummary = ""
        aiService.photoError = nil
    }

    private func logSelectedItems() {
        let date = DatabaseManager.getCurrentDate()
        do {
            let mealID = try DatabaseManager.getOrCreateMealID(date: date, mealName: mealName)
            for item in selectableItems where item.isSelected {
                try DatabaseManager.addFoodItem(
                    meal_id: mealID,
                    name: item.name,
                    kcal: "\(item.calories)kcal",
                    pro: "\(item.protein)gm",
                    fat: "\(item.fat)gm",
                    cho: "\(item.carbs)gm",
                    serving: item.portionDescription,
                    qty: "1"
                )
            }
            savedSuccessfully = true
        } catch {
            saveError = "Failed to log items: \(error.localizedDescription)"
        }
    }
}
