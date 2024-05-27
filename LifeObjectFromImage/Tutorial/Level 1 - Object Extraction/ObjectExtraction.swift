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
    
    /* code related to image extraction */
    @StateObject private var viewModel = ImageAnalysisViewModel()
    @State private var extractedObjectImage: UIImage?
    @State private var imageForAllSelectedObjects: UIImage?
    
    /* code related to error reporting */
    @State private var errorMessage: String?
    
    var body: some View {
        
        ScrollView {
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
                            do {
                                // load the image
                                guard let loadedImageData = try await newValue.first?.loadTransferable(type: Data.self),
                                      let loadedImage = UIImage(data: loadedImageData) else { return }
                                self.userPickedImage = loadedImage
                                // analyze this image
                                self.detectedObjects = try await self.viewModel.analyzeImage(loadedImage)
                            } catch {
                                self.errorMessage = error.localizedDescription
                            }
                        }
                    }
                /* */
                
                if let userPickedImage {
                    VStack {
                        Text("Image picked")
                            .font(.headline)
                        ObjectPickableImageView(imageObject: userPickedImage)
                            .scaledToFit()
                            .cornerRadius(20)
                            .frame(height: 350)
                            .environmentObject(viewModel)
                            .onTapGesture { tappedLocation in
                                Task { @MainActor in
                                    if let tappedSubject = await self.viewModel.interaction.subject(at: tappedLocation) {
                                        // select or de-select it
                                        if self.viewModel.interaction.highlightedSubjects.contains(tappedSubject) {
                                            self.viewModel.interaction.highlightedSubjects.remove(tappedSubject)
                                        } else {
                                            self.viewModel.interaction.highlightedSubjects.insert(tappedSubject)
                                        }
                                    }
                                }
                            }
                    }
                }
                
                HStack {
                    
                    if let extractedObjectImage {
                        VStack {
                            Text("Single object")
                                .font(.headline)
                            Image(uiImage: extractedObjectImage)
                                .resizable()
                                .scaledToFit()
                                .padding()
                                .background {
                                    RoundedRectangle(cornerRadius: 10)
                                        .foregroundStyle(.teal)
                                }
                                .frame(height: 300)
                        }
                    }
                    
                    if let imageForAllSelectedObjects {
                        VStack {
                            Text("All objects")
                                .font(.headline)
                            Image(uiImage: imageForAllSelectedObjects)
                                .resizable()
                                .scaledToFit()
                                .padding()
                                .background {
                                    RoundedRectangle(cornerRadius: 10)
                                        .foregroundStyle(.teal)
                                }
                                .frame(height: 300)
                        }
                    }
                    
                    
                }
                .padding()
                
                Text("Detected objects count")
                    .font(.headline)
                
                Text("\(self.detectedObjects.count)")
                
                LazyVGrid(columns: [
                    .init(.flexible()),
                    .init(.flexible())
                ]) {
                    ForEach(self.detectedObjects.sorted(by: { one, two in
                        return one.bounds.minX < two.bounds.minX
                    }), id: \.hashValue) { object in
                        VStack(alignment: .leading) {
                            Text("Position: x \(object.bounds.origin.x) y \(object.bounds.origin.y)")
                            Text("Size: width \(object.bounds.width) height \(object.bounds.height)")
                            Text("Object hash: \(object.hashValue)")
                            // highlight
                            Button("Select") {
                                self.viewModel.interaction.highlightedSubjects.insert(object)
                                // generate an image with all currently highlighted objects
                                Task { @MainActor in
                                    do {
                                        try await generateImageForAllSelectedObjects()
                                    } catch {
                                        self.errorMessage = error.localizedDescription
                                    }
                                }
                            }
                            // extract this to an image
                            Button("Extract") {
                                Task { @MainActor in
                                    if let objectImage = try? await object.image {
                                        self.extractedObjectImage = objectImage
                                    }
                                }
                            }
                            // remove selection
                            Button("Un-select") {
                                self.viewModel.interaction.highlightedSubjects.remove(object)
                                // generate an image with all currently highlighted objects
                                Task { @MainActor in
                                    do {
                                        try await generateImageForAllSelectedObjects()
                                    } catch {
                                        self.errorMessage = error.localizedDescription
                                    }
                                }
                            }
                        }
                        .padding()
                        .background {
                            RoundedRectangle(cornerRadius: 20)
                                .foregroundStyle(Color(uiColor: .systemGroupedBackground))
                        }
                    }
                }
                
                Text("Long press on an object within the image to copy.")
                
            }
        }
        .alert(item: $errorMessage) { message in
            Alert(title: Text("Error while analyzing objects within the image"), message: Text(message))
        }
        
    }
    
    func generateImageForAllSelectedObjects() async throws {
        let allSubjectsImage = try await self.viewModel.interaction.image(for: self.viewModel.interaction.highlightedSubjects)
        self.imageForAllSelectedObjects = allSubjectsImage
    }
    
}

extension String: Identifiable {
    public var id: String { return self }
}
