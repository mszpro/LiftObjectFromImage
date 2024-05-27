//
//  ObjectPickableImageView.swift
//  LifeObjectFromImage
//
//  Created by Msz on 2024/05/25.
//

import Foundation
import UIKit
import SwiftUI
import VisionKit
import Combine

@MainActor
class ImageAnalysisViewModel: NSObject, ObservableObject {
    let analyzer = ImageAnalyzer()
    let interaction = ImageAnalysisInteraction()
    var loadedImageView: UIImageView?
    
    func analyzeImage(_ image: UIImage) async throws -> Set<ImageAnalysisInteraction.Subject> {
        let configuration = ImageAnalyzer.Configuration([.visualLookUp])
        let analysis = try await analyzer.analyze(image, configuration: configuration)
        interaction.analysis = analysis
        let detectedSubjects = await interaction.subjects
        return detectedSubjects
    }
}

@MainActor
struct ObjectPickableImageView: UIViewRepresentable {
    
    var imageObject: UIImage
    
    @EnvironmentObject var viewModel: ImageAnalysisViewModel
    
    func makeUIView(context: Context) -> CustomizedUIImageView {
        let imageView = CustomizedUIImageView()
        
        // configure the view with image object and analyzer interaction
        imageView.image = imageObject
        imageView.contentMode = .scaleAspectFit
        viewModel.interaction.preferredInteractionTypes = [.imageSubject]
        imageView.addInteraction(viewModel.interaction)
        
        viewModel.loadedImageView = imageView
        
        return imageView
    }
    
    func updateUIView(_ uiView: CustomizedUIImageView, context: Context) { }
    
}

class CustomizedUIImageView: UIImageView {
    override var intrinsicContentSize: CGSize {
        .zero
    }
}
