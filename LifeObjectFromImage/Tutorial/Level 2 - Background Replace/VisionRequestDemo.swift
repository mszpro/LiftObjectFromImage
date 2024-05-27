//
//  VisionSegmentationRequestDemo.swift
//  LifeObjectFromImage
//
//  Created by Msz on 2024/05/27.
//

import SwiftUI
import PhotosUI
import Vision

struct VisionRequestDemo: View {
    
    enum RequestError: Error, LocalizedError {
        case failedToGetCIImage
        case noSubjectsDetected
        
        var errorDescription: String? {
            switch self {
                case .failedToGetCIImage:
                    return "Failed to get CIImage from the provided image."
                case .noSubjectsDetected:
                    return "No subjects were detected in the image."
            }
        }
    }
    
    /* code related to image picking */
    @State private var userPickedImage: UIImage?
    @State private var userPickedImageItem: [PhotosPickerItem] = []
    
    /* results */
    @State private var imageAnalysisResults: [VNInstanceMaskObservation] = []
    
    /* error reporting */
    @State private var errorMessage: String?
    
    var body: some View {
        
        VStack {
            
            /* image picker */
            PhotosPicker(
                selection: $userPickedImageItem,
                maxSelectionCount: 1,
                matching: .images) {
                    Image(systemName: "photo")
                }
                .onChange(of: userPickedImageItem) { _, newValue in
                    Task { @MainActor in
                        guard let loadedImageData = try? await newValue.first?.loadTransferable(type: Data.self),
                              let loadedImage = UIImage(data: loadedImageData) else { return }
                        self.userPickedImage = loadedImage
                        do {
                            try performAnalysis(forPicked: loadedImage)
                        } catch {
                            self.errorMessage = error.localizedDescription
                        }
                    }
                }
            
            /* image preview */
            if let userPickedImage {
                Image(uiImage: userPickedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 300)
            }
            
            /* analysis result */
            List {
                ForEach(self.imageAnalysisResults, id: \.uuid) { result in
                    VStack(alignment: .leading) {
                        Text(result.uuid.uuidString)
                            .font(.headline)
                        Text(result.description)
                        Button("Get masked image") {
                            
                        }
                    }
                }
            }
            
        }
        .alert(item: $errorMessage) { message in
            Alert(title: Text("Error while analyzing objects within the image"), message: Text(message))
        }
        
    }
    
    func performAnalysis(forPicked: UIImage) throws {
        guard let ciImg = CIImage(image: forPicked) else {
            throw RequestError.failedToGetCIImage
        }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(ciImage: ciImg)
        try handler.perform([request])
        
        guard let result = request.results else {
            throw RequestError.noSubjectsDetected
        }
        
        DispatchQueue.main.async {
            self.imageAnalysisResults = result
        }
    }
    
}

#Preview {
    VisionRequestDemo()
}
