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

@MainActor
public struct ObjectPickableImageView: UIViewRepresentable {
    
    /* input to this view */
    var imageObject: UIImage
    @Binding var errorMessage: String?
    @Binding var detectedObjects: Set<ImageAnalysisInteraction.Subject>
    @Binding var selectedObjects: Set<ImageAnalysisInteraction.Subject>
    
    /* objects used for displaying the image, and analyzing the content */
    private let imageView = CustomizedUIImageView()
    private let analyzer = ImageAnalyzer()
    private let interaction = ImageAnalysisInteraction()
    
    public func makeUIView(context: Context) -> UIImageView {
        imageView.image = imageObject
        imageView.contentMode = .scaleAspectFit
        interaction.preferredInteractionTypes = .imageSubject
        imageView.addInteraction(interaction)
        // run image analysis
        Task { @MainActor in
            do {
                let configuration = ImageAnalyzer.Configuration([.visualLookUp])
                let analysis = try await analyzer.analyze(imageObject, configuration: configuration)
                interaction.analysis = analysis
                let detectedSubjects = await interaction.subjects
                self.detectedObjects = detectedSubjects
                interaction.highlightedSubjects = self.selectedObjects
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
        return imageView
    }
    
    public func updateUIView(_ uiView: UIImageView, context: Context) {
        self.interaction.highlightedSubjects = self.selectedObjects
    }
    
}

fileprivate class CustomizedUIImageView: UIImageView {
    override var intrinsicContentSize: CGSize {
        .zero
    }
}
