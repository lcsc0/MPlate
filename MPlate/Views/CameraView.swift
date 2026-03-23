//
//  CameraView.swift
//  MPlate
//
//  UIViewControllerRepresentable wrapper around UIImagePickerController.
//  Accepts a sourceType (defaults to .camera, falls back to .photoLibrary
//  if camera is unavailable) and an onCapture callback.
//

import SwiftUI
import UIKit

struct CameraView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    var sourceType: UIImagePickerController.SourceType = .camera
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        let resolvedSource: UIImagePickerController.SourceType
        if UIImagePickerController.isSourceTypeAvailable(sourceType) {
            resolvedSource = sourceType
        } else {
            resolvedSource = .photoLibrary
        }
        picker.sourceType = resolvedSource
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: dismiss)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let dismiss: DismissAction

        init(onCapture: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
