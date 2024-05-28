//
//  VisionSegmentationRequestDemo.swift
//  LifeObjectFromImage
//
//  Created by Msz on 2024/05/27.
//

import SwiftUI
import PhotosUI
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

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
    
    /* code related to background image picking */
    @State private var userPickedBackgroundImage: UIImage?
    @State private var userPickedImageItem_background: [PhotosPickerItem] = []
    
    /* results */
    @State private var imageRequestHandler: VNImageRequestHandler?
    @State private var imageAnalysisResults: [VNInstanceMaskObservation] = []
    @State private var maskedImagePreview: UIImage?
    @State private var extractedSubjectImage: UIImage?
    @State private var backgroundReplacedImage: UIImage?
    
    /* error reporting */
    @State private var errorMessage: String?
    
    var body: some View {
        
        VStack {
            
            /* image picker */
            PhotosPicker(
                selection: $userPickedImageItem,
                maxSelectionCount: 1,
                matching: .images) {
                    Label("Pick image", systemImage: "photo")
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
            
            /* image picker for background image replacement */
            PhotosPicker(
                selection: $userPickedImageItem_background,
                maxSelectionCount: 1,
                matching: .images) {
                    Label("Pick image for background replacement", systemImage: "photo")
                }
                .onChange(of: userPickedImageItem_background) { _, newValue in
                    Task { @MainActor in
                        guard let loadedImageData = try? await newValue.first?.loadTransferable(type: Data.self),
                              let loadedImage = UIImage(data: loadedImageData) else { return }
                        self.userPickedBackgroundImage = loadedImage
                    }
                }
            
            /* image preview */
            HStack {
                if let userPickedImage {
                    Image(uiImage: userPickedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 300)
                }
                
                if let maskedImagePreview {
                    Image(uiImage: maskedImagePreview)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 300)
                }
            }
            
            HStack {
                if let userPickedBackgroundImage {
                    Image(uiImage: userPickedBackgroundImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 300)
                }
                
                if let extractedSubjectImage {
                    Image(uiImage: extractedSubjectImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 300)
                }
            }
            
            /* analysis result */
            List {
                ForEach(self.imageAnalysisResults, id: \.uuid) { result in
                    VStack(alignment: .leading) {
                        Text(result.uuid.uuidString)
                            .font(.headline)
                        Text(result.description)
                        Button("Get masked image") {
                            guard let firstObservation = self.imageAnalysisResults.first,
                                  let imageRequestHandler,
                                  let mask = try? firstObservation.generateScaledMaskForImage(forInstances: firstObservation.allInstances, from: imageRequestHandler) else {
                                return
                            }
                            let ciImg = CIImage(cvPixelBuffer: mask)
                            self.maskedImagePreview = convertMonochromeToColoredImage(monochromeImage: ciImg, color: .blue)
                            // Get the subject only image
                            guard let userPickedImage,
                                  let userPickedImage_CI = CIImage(image: userPickedImage) else {
                                return
                            }
                            guard let subjectOnlyImage = apply(mask: ciImg, toImage: userPickedImage_CI, backgroundImage: self.userPickedBackgroundImage) else {
                                return
                            }
                            self.extractedSubjectImage = subjectOnlyImage
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
        self.imageRequestHandler = handler
        
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

func convertMonochromeToColoredImage(monochromeImage: CIImage, color: UIColor) -> UIImage? {
    // Create a color filter
    let colorFilter = CIFilter(name: "CIColorMonochrome")
    colorFilter?.setValue(monochromeImage, forKey: kCIInputImageKey)
    colorFilter?.setValue(CIColor(color: color), forKey: kCIInputColorKey)
    colorFilter?.setValue(1.0, forKey: kCIInputIntensityKey)
    
    // Get the output CIImage from the filter
    guard let outputImage = colorFilter?.outputImage else {
        return nil
    }
    
    // Convert the CIImage to UIImage
    let context = CIContext()
    if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
        return UIImage(cgImage: cgImage)
    }
    
    return nil
}

func apply(mask: CIImage, toImage image: CIImage, backgroundImage: UIImage? = nil) -> UIImage? {
    // Convert the optional UIImage to CIImage and resize/crop it if provided
    let inputExtent = image.extent
    var backgroundTransformed: CIImage?
    if let backgroundImage = backgroundImage, let backgroundCIImage = CIImage(image: backgroundImage) {
        backgroundTransformed = backgroundCIImage
            .transformed(by: CGAffineTransform(scaleX: inputExtent.width / backgroundCIImage.extent.width, y: inputExtent.height / backgroundCIImage.extent.height))
            .cropped(to: inputExtent)
    }
    
    let filter = CIFilter(name: "CIBlendWithMask")
    filter?.setValue(image, forKey: kCIInputImageKey)
    filter?.setValue(mask, forKey: kCIInputMaskImageKey)
    if let backgroundTransformed = backgroundTransformed {
        filter?.setValue(backgroundTransformed, forKey: kCIInputBackgroundImageKey)
    }
    
    guard let outputCIImg = filter?.outputImage else {
        print("Error: Filter output image is nil")
        return nil
    }
    
    if outputCIImg.extent.isInfinite || outputCIImg.extent.isEmpty {
        print("Error: The resulting image has an invalid extent")
        return nil
    }
    
    // Convert the CIImage to UIImage
    let context = CIContext()
    guard let cgImage = context.createCGImage(outputCIImg, from: outputCIImg.extent) else {
        return nil
    }
    
    return UIImage(cgImage: cgImage)
}
