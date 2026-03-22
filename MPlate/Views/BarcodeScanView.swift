//
//  BarcodeScanView.swift
//  MPlate
//

import SwiftUI
import AVFoundation
import VisionKit

// MARK: - Open Food Facts response models
private struct OFFResponse: Codable {
    let status: Int
    let product: OFFProduct?
}

private struct OFFProduct: Codable {
    let product_name: String?
    let serving_size: String?
    let nutriments: OFFNutriments?
}

private struct OFFNutriments: Codable {
    let energyKcal100g: Double?
    let proteins100g: Double?
    let fat100g: Double?
    let carbohydrates100g: Double?
    let energyKcalServing: Double?
    let proteinsServing: Double?
    let fatServing: Double?
    let carbohydratesServing: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case proteins100g = "proteins_100g"
        case fat100g = "fat_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case energyKcalServing = "energy-kcal_serving"
        case proteinsServing = "proteins_serving"
        case fatServing = "fat_serving"
        case carbohydratesServing = "carbohydrates_serving"
    }
}

// MARK: - DataScanner wrapper
@available(iOS 16.0, *)
struct DataScannerView: UIViewControllerRepresentable {
    let onBarcodeFound: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .fast,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onBarcodeFound: onBarcodeFound)
    }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onBarcodeFound: (String) -> Void
        private var lastScanned: String?

        init(onBarcodeFound: @escaping (String) -> Void) {
            self.onBarcodeFound = onBarcodeFound
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .barcode(let barcode) = item, let value = barcode.payloadStringValue, value != lastScanned {
                    lastScanned = value
                    dataScanner.stopScanning()
                    onBarcodeFound(value)
                    return
                }
            }
        }
    }
}

// MARK: - Main Scan View
struct BarcodeScanView: View {
    @State private var isScanning = true
    @State private var isLoading = false
    @State private var scannedBarcode: String?
    @State private var productName = ""
    @State private var kcal = ""
    @State private var pro = ""
    @State private var fat = ""
    @State private var cho = ""
    @State private var serving = ""
    @State private var showResult = false
    @State private var errorMessage: String?
    @State private var savedConfirmation = false
    @State private var cameraPermission: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    var body: some View {
        NavigationStack {
            Group {
                if cameraPermission == .denied || cameraPermission == .restricted {
                    permissionDeniedView
                } else if showResult {
                    resultForm
                } else if isLoading {
                    loadingView
                } else {
                    scannerView
                }
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Scanner
    private var scannerView: some View {
        ZStack {
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                DataScannerView { barcode in
                    scannedBarcode = barcode
                    lookUpBarcode(barcode)
                }
                .ignoresSafeArea()

                VStack {
                    Spacer()
                    Text("Point at a food barcode")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.55))
                        .clipShape(Capsule())
                        .padding(.bottom, 40)
                }
            } else {
                // Fallback for simulator / unsupported
                VStack(spacing: 20) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 80))
                        .foregroundStyle(Color.mBlue)
                    Text("Camera scanner not available on this device.")
                        .foregroundStyle(Color.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Enter Barcode Manually") {
                        showManualBarcodeEntry()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.mBlue)
                }
            }
        }
        .onAppear {
            cameraPermission = AVCaptureDevice.authorizationStatus(for: .video)
            if cameraPermission == .notDetermined {
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    DispatchQueue.main.async {
                        cameraPermission = AVCaptureDevice.authorizationStatus(for: .video)
                    }
                }
            }
        }
    }

    // MARK: - Loading
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Looking up barcode…")
                .foregroundStyle(Color.gray)
        }
    }

    // MARK: - Result Form
    private var resultForm: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.mBlue)
                    .padding(.top, 20)

                Text("Found: \(scannedBarcode ?? "")")
                    .font(.caption)
                    .foregroundStyle(Color.gray)

                if let err = errorMessage {
                    Text(err)
                        .foregroundStyle(Color.red)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Group {
                    labeledField("Name", text: $productName)
                    labeledField("Calories (kcal)", text: $kcal, keyboard: .numberPad)
                    labeledField("Protein (g)", text: $pro, keyboard: .numberPad)
                    labeledField("Fat (g)", text: $fat, keyboard: .numberPad)
                    labeledField("Carbs (g)", text: $cho, keyboard: .numberPad)
                    labeledField("Serving size", text: $serving)
                }
                .padding(.horizontal)

                if savedConfirmation {
                    Text("Saved to Custom Items ✓")
                        .font(.subheadline)
                        .foregroundStyle(Color.green)
                }

                HStack(spacing: 16) {
                    Button("Save to Custom") {
                        saveToCustom()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.mBlue)
                    .disabled(productName.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button("Scan Again") {
                        resetScanner()
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.mBlue)
                }
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Permission Denied
    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.slash")
                .font(.system(size: 60))
                .foregroundStyle(Color.gray)
            Text("Camera access is required to scan barcodes.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.gray)
                .padding(.horizontal)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.mBlue)
        }
    }

    // MARK: - Helpers
    private func labeledField(_ label: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.gray)
            TextField(label, text: text)
                .textFieldStyle(.roundedBorder)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
        }
    }

    private func lookUpBarcode(_ barcode: String) {
        isLoading = true
        isScanning = false
        errorMessage = nil

        let urlStr = "https://world.openfoodfacts.org/api/v0/product/\(barcode).json"
        guard let url = URL(string: urlStr) else {
            showError("Invalid barcode.")
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                isLoading = false
                guard let data = data, error == nil else {
                    showError("Network error. Check your connection.")
                    return
                }
                do {
                    let response = try JSONDecoder().decode(OFFResponse.self, from: data)
                    if response.status == 1, let product = response.product {
                        populate(from: product)
                        showResult = true
                    } else {
                        errorMessage = "Product not found in database. Fill in the fields manually."
                        productName = ""
                        kcal = ""; pro = ""; fat = ""; cho = ""; serving = ""
                        showResult = true
                    }
                } catch {
                    showError("Could not parse product data.")
                }
            }
        }.resume()
    }

    private func populate(from product: OFFProduct) {
        productName = product.product_name ?? ""
        serving = product.serving_size ?? "1 serving"

        let n = product.nutriments
        // Prefer per-serving values, fall back to per-100g
        kcal = formatNutrient(n?.energyKcalServing ?? n?.energyKcal100g)
        pro  = formatNutrient(n?.proteinsServing ?? n?.proteins100g)
        fat  = formatNutrient(n?.fatServing ?? n?.fat100g)
        cho  = formatNutrient(n?.carbohydratesServing ?? n?.carbohydrates100g)
    }

    private func formatNutrient(_ value: Double?) -> String {
        guard let v = value else { return "" }
        return v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v)
    }

    private func showError(_ msg: String) {
        errorMessage = msg
        productName = ""
        kcal = ""; pro = ""; fat = ""; cho = ""; serving = ""
        showResult = true
    }

    private func saveToCustom() {
        let sanitizedName = productName.trimmingCharacters(in: .whitespaces).isEmpty ? "Scanned Item" : productName.trimmingCharacters(in: .whitespaces)
        let sanitizedKcal = (kcal.isEmpty ? "0" : kcal) + "kcal"
        let sanitizedPro  = (pro.isEmpty  ? "0" : pro)  + "gm"
        let sanitizedFat  = (fat.isEmpty  ? "0" : fat)  + "gm"
        let sanitizedCho  = (cho.isEmpty  ? "0" : cho)  + "gm"
        let sanitizedServing = serving.isEmpty ? "1 serving" : serving

        do {
            try DatabaseManager.addCustomItem(
                name: sanitizedName,
                kcal: sanitizedKcal,
                pro: sanitizedPro,
                fat: sanitizedFat,
                cho: sanitizedCho,
                serving: sanitizedServing
            )
            savedConfirmation = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                savedConfirmation = false
            }
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }

    private func resetScanner() {
        showResult = false
        isLoading = false
        isScanning = true
        scannedBarcode = nil
        productName = ""; kcal = ""; pro = ""; fat = ""; cho = ""; serving = ""
        errorMessage = nil
        savedConfirmation = false
    }

    private func showManualBarcodeEntry() {
        // Jump straight to the result form with blank fields
        showResult = true
        errorMessage = "Enter nutrition info manually."
    }
}
