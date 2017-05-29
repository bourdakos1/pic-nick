//
//  CameraView.swift
//  Visual Recognition
//
//  Created by Nicholas Bourdakos on 3/17/17.
//  Copyright © 2017 Nicholas Bourdakos. All rights reserved.
//

import UIKit
import AVFoundation

class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    
    // Set the StatusBar color.
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    // Camera variables.
    var captureSession: AVCaptureSession?
    var photoOutput: AVCapturePhotoOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    @IBOutlet var cameraView: UIView!
    @IBOutlet var tempImageView: UIImageView!
    
    // All the buttons.
    @IBOutlet var captureButton: UIButton!
    @IBOutlet var retakeButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initializeCamera()

        // Retake just resets the UI.
        retake()
        view.bringSubview(toFront: captureButton)
    }
    
    // Initialize camera.
    func initializeCamera() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = AVCaptureSessionPreset1920x1080
        let backCamera = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        
        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            captureSession?.addInput(input)
            photoOutput = AVCapturePhotoOutput()
            if (captureSession?.canAddOutput(photoOutput) != nil){
                captureSession?.addOutput(photoOutput)
                
                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                previewLayer?.videoGravity = AVLayerVideoGravityResizeAspect
                previewLayer?.connection.videoOrientation = AVCaptureVideoOrientation.portrait
                cameraView.layer.addSublayer(previewLayer!)
                captureSession?.startRunning()
            }
        } catch {
            print("Error: \(error)")
        }
        previewLayer?.frame = view.bounds
    }

    
    // Delegate for Camera.
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        
        if photoSampleBuffer != nil {
            let imageData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(
                forJPEGSampleBuffer: photoSampleBuffer!,
                previewPhotoSampleBuffer: previewPhotoSampleBuffer
            )
            
            let dataProvider  = CGDataProvider(data: imageData! as CFData)
            
            let cgImageRef = CGImage(
                jpegDataProviderSource: dataProvider!,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
            )
            
            let image = UIImage(
                cgImage: cgImageRef!,
                scale: 1.0,
                orientation: UIImageOrientation.right
            )
            
            let reducedImage = image.resized(toWidth: 300)!
            
            let classifierId = UserDefaults.standard.string(forKey: "classifier_id")
            
            let url = "https://gateway-a.watsonplatform.net/visual-recognition/api/v3/classify"
            
            var r = URLRequest(url: URL(string: url)!)
            
            r.query(params: [
                "api_key": apiKey!,
                "version": "2016-05-20",
                "threshold": "0",
                "classifier_ids": "\(classifierId ?? "default")"
            ])
            
            // Attach the small image at 40% quality.
            r.attach(
                jpeg: UIImageJPEGRepresentation(reducedImage, 0.4)!,
                filename: "test.jpg"
            )
            
            let task = URLSession.shared.dataTask(with: r) { data, response, error in
                // Check for fundamental networking error.
                guard let data = data, error == nil else {
                    return
                }
                
                var json: AnyObject?
                
                do {
                    json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as AnyObject
                } catch {
                    print("Error: \(error)")
                }
                
                guard let images = json?["images"] as? [Any],
                    let image = images.first as? [String: Any],
                    let classifiers = image["classifiers"] as? [Any],
                    let classifier = classifiers.first as? [String: Any],
                    let classes = classifier["classes"] as? [Any] else {
                        print("Error: No classes returned.")
                        var myNewData = [[String: Any]]()
                        
                        myNewData.append([
                            "class_name": "No classes found" as Any,
                            "score": CGFloat(0.0) as Any
                        ])
                        self.push(data: myNewData)
                        return
                }
                
                var myNewData = [[String: Any]]()
                
                for case let classObj as [String: Any] in classes {
                    myNewData.append([
                        "class_name": classObj["class"] as Any,
                        "score": classObj["score"] as Any
                    ])
                }
                
                // Sort data by score and reload table.
                myNewData = myNewData.sorted(by: { $0["score"] as! CGFloat > $1["score"] as! CGFloat})
                self.push(data: myNewData)
            }
            task.resume()
            
            // Set the screen to our captured photo.
            tempImageView.image = image
            tempImageView.isHidden = false
        }
    }
    
    @IBAction func unwindToVC(segue: UIStoryboardSegue) {
        
    }
    
    @IBAction func takePhoto() {
        photoOutput?.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        captureButton.isHidden = true
        retakeButton.isHidden = false
    }
    
    @IBAction func retake() {
        tempImageView.isHidden = true
        captureButton.isHidden = false
        retakeButton.isHidden = true
    }
}

extension UIImage {
    func resized(withPercentage percentage: CGFloat) -> UIImage? {
        let canvasSize = CGSize(width: size.width * percentage, height: size.height * percentage)
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: canvasSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    func resized(toWidth width: CGFloat) -> UIImage? {
        let canvasSize = CGSize(width: width, height: CGFloat(ceil(width/size.width * size.height)))
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: canvasSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

extension UITextField {
    func setLeftPaddingPoints(_ amount:CGFloat){
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: self.frame.size.height))
        self.leftView = paddingView
        self.leftViewMode = .always
    }
    
    func setRightPaddingPoints(_ amount:CGFloat) {
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: self.frame.size.height))
        self.rightView = paddingView
        self.rightViewMode = .always
    }
}
