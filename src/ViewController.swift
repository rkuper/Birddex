////////////////////////////////////////////////////////////////////////////////
//
// Project: Birddex
//
// Files: ViewController.swift, AppDelegate.swift, birds.mlmodel,
//        Main.storyboard, LaunchScreen.storyboard, Info.plist
// Hackathon: HackNYU 2018
//
// Author: Reese Kuper, Xudong Tang, Yixian Gan, and Atharva Kulkarni
// GitHub: https://github.com/rkuper/Birddex
//
/////////////////////////////// 80 COLUMNS WIDE ////////////////////////////////
//
// Outside Sources Used:
//
// Adam Behringer's cognitive-services-ios-customvision-sample for
// some of the classification framework:
// https://github.com/Azure-Samples/cognitive-services-ios-customvision-sample
//
// Brian Advent's video on view controller segues:
// https://www.youtube.com/watch?v=OZix7etsd8g
//
////////////////////////////////////////////////////////////////////////////////

import UIKit
import AVFoundation
import Vision

var checkTime: TimeInterval = 0 // Sets the time for the last checked time
var rate: TimeInterval = 0.33 // Sets the rate for how fast the checking is
var checkRate = 0.0 // Compares rate to checkRate to reset rate if needed

class ViewController: UIViewController {
    
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var birdCaptureButton: UIButton!
    
    @IBAction func HistorytoMainSegue(segue: UIStoryboardSegue) {
        self.dismiss(animated: false, completion: nil)
    }
    
    @IBAction func MainHistoryButton(_ sender: Any) {
    }

    @IBAction func MainMapButton(_ sender: Any) {
    }
    
    @IBAction func MaptoMainSegue(segue: UIStoryboardSegue) {
        self.dismiss(animated: false, completion: nil)
    }
    
    // Set up for class fields
    let impact = UIImpactFeedbackGenerator() // Haptic Feedback when wikipedia loads, successful capture
    var previewLayer: AVCaptureVideoPreviewLayer! // Sets up the video player preview
    let queue = DispatchQueue(label: "videoQueue") // Makes a DispatchQueue
    var captureSession = AVCaptureSession() // Sets up the Capture Session
    var captureDevice: AVCaptureDevice? // Gets the capture device
    let videoOutput = AVCaptureVideoDataOutput() // Sets up the Video Output
    var garbageCounter = 0 // Tracks meaningless, low-confidence guesses in a row
    let confidenceLevel: Float = 0.88 // Sets up the desired confidence to ensure detection accuracy
    var press = false // Checks for a pressed Button
    var names = [""] // Stores captured names
    var confidence: [Float] = [0.0] // Stores captured probabilities
    var zoomInGestureRecognizer = UISwipeGestureRecognizer() // Set Zoom In function
    var zoomOutGestureRecognizer = UISwipeGestureRecognizer() // Set Zoom Out function
    let targetImageSize = CGSize(width: 227, height: 227) // Load model, must match model data input
    var videoView = UIView() // Video view setup

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Sets up video preview and session
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewView.layer.addSublayer(previewLayer)
        
        // Zoom in functionality
        zoomInGestureRecognizer.direction = .right
        zoomInGestureRecognizer.addTarget(self, action: #selector(zoomIn))
        view.addGestureRecognizer(zoomInGestureRecognizer)
        
        // Zoom out functionality
        zoomOutGestureRecognizer.direction = .left
        zoomOutGestureRecognizer.addTarget(self, action: #selector(zoomOut))
        view.addGestureRecognizer(zoomOutGestureRecognizer)
        
        // tap and hold gestures for bird capturing
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(normalTap(_:)))
        tapGesture.numberOfTapsRequired = 1
        let longGesture = UILongPressGestureRecognizer(target: self, action: #selector(longTap(_:)))
        self.birdCaptureButton.addGestureRecognizer(longGesture)
        self.birdCaptureButton.addGestureRecognizer(tapGesture)
    }
    
    lazy var classificationRequest: [VNRequest] = {
        do {
            // Loads the bird mlmodel, sends request to file, catches a cannot load error
            let model = try VNCoreMLModel(for: birds().model)
            let classificationRequest = VNCoreMLRequest(model: model, completionHandler: self.classify)
            return [classificationRequest]
        } catch {
            print("Unable to load: \(error)")
            abort()
        }
    }()
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let screenSize = videoView.bounds.size
        if let touchPoint = touches.first {
            let x = touchPoint.location(in: videoView).y / screenSize.height
            let y = 1.0 - touchPoint.location(in: videoView).x / screenSize.width
            let focusPoint = CGPoint(x: x, y: y)
            
            if let device = captureDevice {
                do {
                    try device.lockForConfiguration()
                    
                    device.focusPointOfInterest = focusPoint
                    device.focusMode = .autoFocus
                    device.exposurePointOfInterest = focusPoint
                    device.exposureMode = AVCaptureDevice.ExposureMode.continuousAutoExposure
                    device.unlockForConfiguration()
                }
                catch {
                }
            }
        }
    }
    
    // Classification Process
    
    func classify(request: VNRequest, error: Error?) {
        if self.press {
            // Gets observations from the returned classification information
            guard let observations = request.results as? [VNClassificationObservation]
                else { fatalError("That is no classification. How is this possible...") }
            
            // Tests the best result from the batch
            guard let testObservation = observations.first
                else { fatalError("No result.") }
            
            // Checks to see if testObservation is any good/confident. If so, search wiki page for it
            // print("\(testObservation.identifier): \(testObservation.confidence)")
            
            // If the observation was useless, increment garbage counter or
            if testObservation.identifier.starts(with: "Unknown") || testObservation.confidence < confidenceLevel {
                if self.garbageCounter < 5 {
                    self.garbageCounter += 1
                } else {
                    DispatchQueue.main.async{}
                    self.garbageCounter = 0
                }
            } else {
                self.garbageCounter = 0
                DispatchQueue.main.async {
                    
                    let animalName = testObservation.identifier.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    //test
                    if !animalName.elementsEqual("UW Madison"){
                        print (animalName)
                        switch animalName{
                        case "Dog":
                            self.confidence.append(5 * testObservation.confidence)
                        case "Animal":
                            self.confidence.append(0.5 * testObservation.confidence)
                        case "Red Robin":
                            self.confidence.append(10 * testObservation.confidence)
                        case "penguin":
                            self.confidence.append(100000 * testObservation.confidence)
                        default:
                            self.confidence.append(testObservation.confidence)
                        }
                        self.names.append(animalName)
                        print(self.names.count)
                    }
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        cameraSetup()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = previewView.bounds;
    }
    
    @objc func zoomIn () {
        if let zoomFactor = captureDevice?.videoZoomFactor{
            if zoomFactor < 15.0 {
                let newZoomFactor = min(zoomFactor + 1.0, 15.0)
                do {
                    try captureDevice?.lockForConfiguration()
                    captureDevice?.ramp(toVideoZoomFactor: newZoomFactor, withRate: 1.0)
                    captureDevice?.unlockForConfiguration()
                } catch {
                    print(error)
                }
            }
        }
    }
    
    @objc func zoomOut () {
        if let zoomFactor = captureDevice?.videoZoomFactor{
            if zoomFactor > 1.0 {
                let newZoomFactor = max(zoomFactor - 1.0, 1.0)
                do {
                    try captureDevice?.lockForConfiguration()
                    captureDevice?.ramp(toVideoZoomFactor: newZoomFactor, withRate: 1.0)
                    captureDevice?.unlockForConfiguration()
                } catch {
                    print(error)
                }
            }
        }
    }
    
    @objc func normalTap(_ sender: UIGestureRecognizer){
    }
    
    @objc func longTap(_ sender: UILongPressGestureRecognizer){
        if sender.state == .ended {
            print("UIGestureRecognizerStateEnded")
            self.press = false
            openWiki()
            names = [""]
            confidence = [0.0]
        }
        else if sender.state == .began {
            print("UIGestureRecognizerStateBegan.")
            self.press = true
        }
    }
    
    @objc func openWiki(){
        var animalName = mostProbableObject()
        if !(animalName.elementsEqual("UW Madison")) {
            animalName = animalName.replacingOccurrences(of: " ", with: "_")
            if let url = URL(string: "http://www.wikipedia.org/wiki/" + animalName) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }
    
    func mostProbableObject() -> String {
        var i = 0
        var j = 0;
        var animalsInTheList = [""]
        var totalConfidence: [Float] = [0.0]
        while i < names.count {
            var existed = false
            while j < animalsInTheList.count {
                if names[i].isEqual(animalsInTheList[j]) {
                    totalConfidence[j] += confidence[i]
                    existed = true
                    break
                } else{
                    j += 1
                    continue
                }
            }
            if !existed {
                animalsInTheList.append(names[i])
                totalConfidence.append(confidence[i])
            }
            j = 0
            i += 1
        }
        j = 0
        var maxIndex = 0
        while j < totalConfidence.count {
            if totalConfidence[j] >= totalConfidence[maxIndex] {
                maxIndex = j
            }
            j += 1
        }
        //
        return animalsInTheList[maxIndex]
    }
    
    func cameraSetup() {
        let backCamera = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back)
        
        if let device = backCamera.devices.last {
            captureDevice = device
            beginSession()
        }
    }
    
    func beginSession() {
        do {
            videoOutput.videoSettings = [((kCVPixelBufferPixelFormatTypeKey as NSString) as String) : (NSNumber(value: kCVPixelFormatType_32BGRA) as! UInt32)]
            videoOutput.setSampleBufferDelegate(self, queue: queue)
            videoOutput.alwaysDiscardsLateVideoFrames = true

            captureSession.sessionPreset = .hd1920x1080
            if captureSession.outputs.isEmpty {
                captureSession.addOutput(videoOutput)
            }
            
            let input = try AVCaptureDeviceInput(device: captureDevice!)
            if (captureSession.inputs.isEmpty) {
                captureSession.addInput(input)
            }
            
            captureSession.startRunning()
        } catch {
            print("error connecting to capture device")
        }
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    // called for each frame of video
    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        let curTime = NSDate.timeIntervalSinceReferenceDate
        checkRate = curTime - checkTime
        
        guard let croppedBuffer = croppedSampleBuffer(sampleBuffer, targetSize: targetImageSize) else {
            return
        }
        
        do {
            let classifierRequestHandler = VNImageRequestHandler(cvPixelBuffer: croppedBuffer, options: [:])
            try classifierRequestHandler.perform(classificationRequest)
        } catch {
            print(error)
        }
    }
}

let context = CIContext()
var rotateTransform: CGAffineTransform?
var scaleTransform: CGAffineTransform?
var cropTransform: CGAffineTransform?
var resultBuffer: CVPixelBuffer?

func croppedSampleBuffer(_ sampleBuffer: CMSampleBuffer, targetSize: CGSize) -> CVPixelBuffer? {
    
    guard let imageBuffer: CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
        fatalError("Can't convert to CVImageBuffer.")
    }
    
    // Set image specifications for efficiency
    if rotateTransform == nil {
        let imageSize = CVImageBufferGetEncodedSize(imageBuffer)
        let rotatedSize = CGSize(width: imageSize.height, height: imageSize.width)
        
        guard targetSize.width < rotatedSize.width, targetSize.height < rotatedSize.height else {
            fatalError("Captured image is smaller than image size for model.")
        }
        
        let shorterSize = (rotatedSize.width < rotatedSize.height) ? rotatedSize.width : rotatedSize.height
        rotateTransform = CGAffineTransform(translationX: imageSize.width / 2.0, y: imageSize.height / 2.0).rotated(by: -CGFloat.pi / 2.0).translatedBy(x: -imageSize.height / 2.0, y: -imageSize.width / 2.0)
        
        let scale = targetSize.width / shorterSize
        scaleTransform = CGAffineTransform(scaleX: scale, y: scale)
        
        // Crop input image to output size
        let xDiff = rotatedSize.width * scale - targetSize.width
        let yDiff = rotatedSize.height * scale - targetSize.height
        cropTransform = CGAffineTransform(translationX: xDiff/2.0, y: yDiff/2.0)
    }
    
    // CIImageas are easy to use
    let ciImage = CIImage(cvImageBuffer: imageBuffer)
    let rotated = ciImage.transformed(by: rotateTransform!)
    let scaled = rotated.transformed(by: scaleTransform!)
    let cropped = scaled.transformed(by: cropTransform!)
    
    // Create buffer once, use every time
    if resultBuffer == nil {
        let result = CVPixelBufferCreate(kCFAllocatorDefault, Int(targetSize.width), Int(targetSize.height), kCVPixelFormatType_32BGRA, nil, &resultBuffer)
        
        guard result == kCVReturnSuccess else {
            fatalError("Can't allocate pixel buffer.")
        }
    }
    
    // Render the Core Image pipeline to the buffer
    context.render(cropped, to: resultBuffer!)

    return resultBuffer
}
