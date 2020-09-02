/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Contains the object recognition view controller for the Breakfast Finder.
*/

import UIKit
import AVFoundation
import Vision

protocol ObjectDetectorDelegate {
    func updateLayerGeometry()
    func createRoundedRectLayerWithBounds(_ bounds: CGRect, confidence: VNConfidence)
//    func createbox(_ bounds: CGRect, color: UIColor)
    func removeOldLayer()
    
}

class ObjectDetector: NSObject {
    var bufferSize: CGSize = .zero
    var delegate : ObjectDetectorDelegate?
    init(delegate:ObjectDetectorDelegate){
        self.delegate = delegate
    }
//    private var detectionOverlay: CALayer! = nil
    
    // Vision parts
    private var requests = [VNRequest]()
    
    @discardableResult
    func setupVision() -> NSError? {
        // Setup Vision parts
        let error: NSError! = nil
        
        guard let modelURL = Bundle.main.url(forResource: "golf2_iou0.1_ct0.4", withExtension: "mlmodelc") else {
            return NSError(domain: "VisionObjectRecognitionViewController", code: -1, userInfo: [NSLocalizedDescriptionKey: "Model file is missing"])
        }
        do {
            let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
            let objectRecognition = VNCoreMLRequest(model: visionModel, completionHandler: { (request, error) in
                DispatchQueue.main.async(execute: {
                    // perform all the UI updates on the main queue
                    if let results = request.results {
                        self.drawVisionRequestResults(results)
                    }
                })
            })
            objectRecognition.imageCropAndScaleOption = .scaleFill
            self.requests = [objectRecognition]
        } catch let error as NSError {
            print("Model loading went wrong: \(error)")
        }
        
        return error
    }
    
    func drawVisionRequestResults(_ results: [Any]) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        delegate?.removeOldLayer()
        
        for observation in results where observation is VNRecognizedObjectObservation {
            guard let objectObservation = observation as? VNRecognizedObjectObservation else {
                continue
            }
            // Select only the label with the highest confidence.
//            let topLabelObservation = objectObservation.labels[0]
            let objectBounds = VNImageRectForNormalizedRect(objectObservation.boundingBox, Int(bufferSize.width), Int(bufferSize.height))
            
            delegate?.createRoundedRectLayerWithBounds(objectBounds, confidence: objectObservation.confidence)
        }
        delegate?.updateLayerGeometry()
        CATransaction.commit()
    }
    
    func captureBufferOutput(pixelBuffer: CVPixelBuffer) {
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try imageRequestHandler.perform(self.requests)
        } catch {
            print(error)
        }
    }
    
    
    
//    func createTextSubLayerInBounds(_ bounds: CGRect, identifier: String, confidence: VNConfidence) -> CATextLayer {
//        let textLayer = CATextLayer()
//        textLayer.name = "Object Label"
//        let formattedString = NSMutableAttributedString(string: String(format: "\(identifier)\nConfidence:  %.2f", confidence))
//        let largeFont = UIFont(name: "Helvetica", size: 24.0)!
//        formattedString.addAttributes([NSAttributedString.Key.font: largeFont], range: NSRange(location: 0, length: identifier.count))
//        textLayer.string = formattedString
//        textLayer.bounds = CGRect(x: 0, y: 0, width: bounds.size.height - 10, height: bounds.size.width - 10)
//        textLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
//        textLayer.shadowOpacity = 0.7
//        textLayer.shadowOffset = CGSize(width: 2, height: 2)
//        textLayer.foregroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.0, 0.0, 0.0, 1.0])
//        textLayer.contentsScale = 2.0 // retina rendering
//        // rotate the layer into screen orientation and scale and mirror
//        textLayer.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: 1.0, y: -1.0))
//        return textLayer
//    }
    
}
