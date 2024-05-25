//
//  SystemProvidedPicker.swift
//  LifeObjectFromImage
//
//  Created by Msz on 2024/05/25.
//

import SwiftUI
import PhotosUI
import VisionKit

struct ObjectExtraction: View {
    
    /* code related to image picking */
    @State private var userPickedImage: UIImage?
    @State private var userPickedImageItem: [PhotosPickerItem] = []
    
    /* image analysis result */
    @State private var detectedObjects: Set<ImageAnalysisInteraction.Subject> = []
    @State private var selectedObjects: Set<ImageAnalysisInteraction.Subject> = []
    
    /* code related to error reporting */
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
                    }
                }
            /* */
            
            /* compatible view that allows user to long press to pick objects */
            if let userPickedImage {
                ObjectPickableImageView(imageObject: userPickedImage, errorMessage: $errorMessage, detectedObjects: $detectedObjects, selectedObjects: $selectedObjects)
                    .frame(width: 300, height: 500)
                    .id("\(userPickedImage.hashValue)\(selectedObjects.hashValue)")
            }
            
            VStack(alignment: .leading) {
                Text("Detected objects count")
                    .font(.headline)
                Text("\(self.detectedObjects.count)")
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .foregroundStyle(.gray)
                    .opacity(0.5)
            }
            
            List {
                ForEach(self.detectedObjects.sorted(by: { one, two in
                    return one.bounds.minX < two.bounds.minX
                }), id: \.hashValue) { object in
                    VStack(alignment: .leading) {
                        Text("Position: x \(object.bounds.origin.x) y \(object.bounds.origin.y)")
                        Text("Size: width \(object.bounds.width) height \(object.bounds.height)")
                        ImageAnalysisInteractionSubject_AsyncImageLoader(subject: object)
                            .frame(width: 300, height: 500)
                            .cornerRadius(15)
                        Button("Select") {
                            self.selectedObjects = [object]
                        }
                    }
                }
            }
            
            Text("Long press on an object within the image to copy.")
            
        }
        .alert(item: $errorMessage) { message in
            Alert(title: Text("Error while analyzing objects within the image"), message: Text(message))
        }
        
    }
    
}

extension String: Identifiable {
    public var id: String { return self }
}

struct ImageAnalysisInteractionSubject_AsyncImageLoader: View {
    
    var subject: ImageAnalysisInteraction.Subject
    
    @State private var loadedImage: UIImage?
    
    var body: some View {
        Group {
            if let loadedImage {
                Image(uiImage: loadedImage)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
                    .task { @MainActor in
                        guard let image = try? await subject.image else { return }
                        self.loadedImage = image
                    }
            }
        }
    }
    
}
