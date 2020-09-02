/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Contains the view controller for the Breakfast Finder.
*/

import UIKit
import AVFoundation
import Vision

//AVCaptureVideoDataOutputSampleBufferDelegate
class ViewController: UIViewController {
    var screenWidth = UIScreen.main.bounds.size.width
    var screenHeight = UIScreen.main.bounds.size.height
//    var bufferSize: CGSize = .zero
    
    var objectDetector : ObjectDetector?
    
    @IBOutlet weak private var previewView: UIView!
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer! = nil
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private var detectionOverlay: CALayer! = nil
    var rootLayer: CALayer! = nil
    
    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
//    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//        // to be implemented in the subclass
//    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        objectDetector = ObjectDetector.init(delegate: self)
        AppUtility.lockOrientation(.landscapeLeft, andRotateTo: .landscapeLeft)
        self.objectDetector?.setupVision()
        self.setupAVCapture()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func setupAVCapture() {
        var deviceInput: AVCaptureDeviceInput!
        
        // Select a video device, make an input
        let videoDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices.first
        do {
            deviceInput = try AVCaptureDeviceInput(device: videoDevice!)
        } catch {
            print("Could not create video device input: \(error)")
            return
        }
        
        session.beginConfiguration()
        session.sessionPreset = AVCaptureSession.Preset.vga640x480 // Model image size is smaller.
        
        // Add a video input
        guard session.canAddInput(deviceInput) else {
            print("Could not add video device input to the session")
            session.commitConfiguration()
            return
        }
        session.addInput(deviceInput)
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            // Add a video data output
            videoDataOutput.alwaysDiscardsLateVideoFrames = false
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        } else {
            print("Could not add video data output to the session")
            session.commitConfiguration()
            return
        }
        let captureConnection = videoDataOutput.connection(with: .video)
        // Always process the frames
        captureConnection?.isEnabled = true
        do {
            try  videoDevice!.lockForConfiguration()
            let dimensions = CMVideoFormatDescriptionGetDimensions((videoDevice?.activeFormat.formatDescription)!)
//            DispatchQueue.main.sync {
            objectDetector!.bufferSize.width = CGFloat(dimensions.width)
            objectDetector!.bufferSize.height = CGFloat(dimensions.height)
//            }
            videoDevice!.unlockForConfiguration()
        } catch {
            print(error)
        }
        session.commitConfiguration()
        
        session.startRunning()
        DispatchQueue.main.async {
            self.previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
            self.previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
            self.previewLayer.connection?.videoOrientation = .landscapeLeft
            self.rootLayer = self.previewView.layer
            self.previewLayer.frame = self.rootLayer.bounds
            self.rootLayer.addSublayer(self.previewLayer)
            self.setupLayers()
            self.startCaptureSession()
            self.updateLayerGeometry()
        }
    }
    
    func startCaptureSession() {
        self.session.startRunning()
    }
    
    func setupLayers() {
    detectionOverlay = CALayer() // container layer that has all the renderings of the observations
    detectionOverlay.name = "DetectionOverlay"
    detectionOverlay.bounds = CGRect(x: 0.0,y: 0.0,width: objectDetector!.bufferSize.width,height: objectDetector!.bufferSize.height)
    detectionOverlay.position = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)
    rootLayer.addSublayer(detectionOverlay)

    }
}


extension ViewController : AVCaptureVideoDataOutputSampleBufferDelegate {
    
//    func captureOutput(_ captureOutput: AVCaptureOutput, didDrop didDropSampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//        // print("frame dropped")
//    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let videoPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        self.objectDetector!.captureBufferOutput(pixelBuffer:videoPixelBuffer)
        }
}


extension ViewController: ObjectDetectorDelegate
{
    func removeOldLayer(){
        detectionOverlay.sublayers = nil // remove all the old recognized objects
    }

    func updateLayerGeometry() {
        let bounds = rootLayer.bounds
        var scale: CGFloat
        
        let xScale: CGFloat = bounds.size.width / CGFloat(objectDetector!.bufferSize.width)
        let yScale: CGFloat = bounds.size.height / CGFloat(objectDetector!.bufferSize.height)
        
        scale = fmax(xScale, yScale)
        if scale.isInfinite {
            scale = 1.0
        }
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        
        detectionOverlay.setAffineTransform(CGAffineTransform(rotationAngle: 0).scaledBy(x: -scale, y: scale))
        detectionOverlay.position = CGPoint (x: bounds.midX, y: bounds.midY)
        
        CATransaction.commit()
        
    }
    
    func createRoundedRectLayerWithBounds(_ bounds: CGRect, confidence: VNConfidence){
        let shapeLayer = CALayer()
        shapeLayer.bounds = bounds
        shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        shapeLayer.name = "Found Object"
        shapeLayer.backgroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [1.0, 1.0, 0.2, 0.4])
        shapeLayer.cornerRadius = 7
        
//        let textLayer = self.createTextSubLayerInBounds(objectBounds,
//                                                        identifier: topLabelObservation.identifier,
//                                                        confidence: topLabelObservation.confidence)
//        shapeLayer.addSublayer(textLayer)
        detectionOverlay.addSublayer(shapeLayer)
    }

}
