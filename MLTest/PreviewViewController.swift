//
//  PreviewViewController.swift
//  MLTest
//
//  Created by Valeriy Kovalevskiy on 7/7/20.
//  Copyright © 2020 Valeriy Kovalevskiy. All rights reserved.
//

import UIKit
import FirebaseMLVisionObjectDetection

final class PreviewViewController: UIViewController {
    //
    let categories = ["Unknown", "Home Goods", "Fashion Goods", "Food", "Places", "Plants"]

    private lazy var annotationOverlayView: UIView = {
      precondition(isViewLoaded)
      let annotationOverlayView = UIView(frame: .zero)
      annotationOverlayView.translatesAutoresizingMaskIntoConstraints = false
      return annotationOverlayView
    }()
    
    
    //MARK: - Properties
    private lazy var vision = Vision.vision()
    private lazy var options: VisionObjectDetectorOptions = {
      let options = VisionObjectDetectorOptions()
      options.shouldEnableClassification = true
      options.shouldEnableMultipleObjects = true
      options.detectorMode = .singleImage
      return options
    }()
    private lazy var objectDetector = vision.objectDetector(options: options)
    var image: UIImage?
    
    //MARK: - Outlets
    @IBOutlet private weak var imageView: UIImageView!
    
    //MAR: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageView.addSubview(annotationOverlayView)
        NSLayoutConstraint.activate([
          annotationOverlayView.topAnchor.constraint(equalTo: imageView.topAnchor),
          annotationOverlayView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
          annotationOverlayView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
          annotationOverlayView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
          ])
        if let image = image {
            imageView.image = image
            DispatchQueue.main.async {
                self.runObjectDetection(with: self.imageView.image!)

            }
        }

    }

    func runObjectDetection(with image: UIImage) {
      let visionImage = VisionImage(image: image)
      objectDetector.process(visionImage) { objects, error in
        self.processResult(from: objects, error: error)
      }
    }

    // MARK: Process the object detection response

    func processResult(from objects: [VisionObject]?, error: Error?) {
      removeDetectionAnnotations()
      guard error == nil else {
        let errorString = error?.localizedDescription ?? Constants.detectionNoResultsMessage
        print("Object detection failed with error: \(errorString)")
        return
      }

      guard let objects = objects, !objects.isEmpty else {
        print("On-Device object detector returned no results.")
        return
      }

      let transform = self.transformMatrix()

      objects.forEach { object in
        drawFrame(object.frame, in: .green, transform: transform)

        let transformedRect = object.frame.applying(transform)
        UIUtilities.addRectangle(
          transformedRect,
          to: self.annotationOverlayView,
          color: .green
        )

        let label = UILabel(frame: transformedRect)
        label.numberOfLines = 2
        label.text = "Category: \(categories[object.classificationCategory.rawValue])\nConfidence: \(object.confidence ?? 0)"
        label.adjustsFontSizeToFitWidth = true
        self.annotationOverlayView.addSubview(label)
      }
    }
}

extension PreviewViewController {
      private func transformMatrix() -> CGAffineTransform {
        guard let image = imageView.image else { return CGAffineTransform() }
        let imageViewWidth = imageView.frame.size.width
        let imageViewHeight = imageView.frame.size.height
        let imageWidth = image.size.width
        let imageHeight = image.size.height

        let imageViewAspectRatio = imageViewWidth / imageViewHeight
        let imageAspectRatio = imageWidth / imageHeight
        let scale = (imageViewAspectRatio > imageAspectRatio) ?
          imageViewHeight / imageHeight :
          imageViewWidth / imageWidth

        // Image view's `contentMode` is `scaleAspectFit`, which scales the image to fit the size of the
        // image view by maintaining the aspect ratio. Multiple by `scale` to get image's original size.
        let scaledImageWidth = imageWidth * scale
        let scaledImageHeight = imageHeight * scale
        let xValue = (imageViewWidth - scaledImageWidth) / CGFloat(2.0)
        let yValue = (imageViewHeight - scaledImageHeight) / CGFloat(2.0)

        var transform = CGAffineTransform.identity.translatedBy(x: xValue, y: yValue)
        transform = transform.scaledBy(x: scale, y: scale)
        return transform
      }

      /// Removes the detection annotations from the annotation overlay view.
      private func removeDetectionAnnotations() {
        for annotationView in annotationOverlayView.subviews {
          annotationView.removeFromSuperview()
        }
      }
    
    
    private func drawFrame(_ frame: CGRect, in color: UIColor, transform: CGAffineTransform) {
      let transformedRect = frame.applying(transform)
      UIUtilities.addRectangle(
        transformedRect,
        to: self.annotationOverlayView,
        color: color
      )
    }
}
fileprivate enum Constants {
  static let lineWidth: CGFloat = 3.0
  static let lineColor = UIColor.yellow.cgColor
  static let fillColor = UIColor.clear.cgColor
  static let smallDotRadius: CGFloat = 5.0
  static let largeDotRadius: CGFloat = 10.0
  static let detectionNoResultsMessage = "No results returned."
  static let failedToDetectObjectsMessage = "Failed to detect objects in image."
  static let maxRGBValue: Float32 = 255.0
  static let topResultsCount: Int = 5
}
