//
//  PhotoViewController.swift
//  CameraKitDemo
//
//  Created by Adrian Mateoaea on 08/01/2019.
//  Copyright © 2019 Wonderkiln. All rights reserved.
//

import UIKit
import CameraKit_iOS
import TensorFlowLite
import CoreLocation
import Alamofire
import AVFoundation

class PhotoPreviewViewController: UIViewController, UIScrollViewDelegate {
        
    var image: UIImage?
    
    @IBOutlet weak var scrollView: UIScrollView!
    
    @IBOutlet weak var imageView: UIImageView!
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.imageView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.imageView.image = self.image
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    @IBAction func handleCancel(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func handleSave(_ sender: Any) {
        if let image = self.image {
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(handleDidCompleteSavingToLibrary(image:error:contextInfo:)), nil)
        }
    }
        
    @objc func handleDidCompleteSavingToLibrary(image: UIImage?, error: Error?, contextInfo: Any?) {
        self.dismiss(animated: true, completion: nil)
    }
}

class PhotoSettingsViewController: UITableViewController {
    
    var squareLayoutConstraint: NSLayoutConstraint!
    var wideLayoutConstraint: NSLayoutConstraint!
    var previewView: CKFPreviewView!
    
    @IBOutlet weak var cameraSegmentControl: UISegmentedControl!
    @IBOutlet weak var flashSegmentControl: UISegmentedControl!
    @IBOutlet weak var faceSegmentControl: UISegmentedControl!
    @IBOutlet weak var gridSegmentControl: UISegmentedControl!
    @IBOutlet weak var modeSegmentControl: UISegmentedControl!
    
    @IBAction func handleCamera(_ sender: UISegmentedControl) {
        if let session = self.previewView.session as? CKFPhotoSession {
            session.cameraPosition = sender.selectedSegmentIndex == 0 ? .back : .front
        }
    }
    
    @IBAction func handleFlash(_ sender: UISegmentedControl) {
        if let session = self.previewView.session as? CKFPhotoSession {
            let values: [CKFPhotoSession.FlashMode] = [.auto, .on, .off]
            session.flashMode = values[sender.selectedSegmentIndex]
        }
    }
    
    @IBAction func handleFace(_ sender: UISegmentedControl) {
        if let session = self.previewView.session as? CKFPhotoSession {
            session.cameraDetection = sender.selectedSegmentIndex == 0 ? .none : .faces
        }
    }
    
    @IBAction func handleGrid(_ sender: UISegmentedControl) {
        self.previewView.showGrid = sender.selectedSegmentIndex == 1
    }
    
    @IBAction func handleMode(_ sender: UISegmentedControl) {
        if let session = self.previewView.session as? CKFPhotoSession {
            if sender.selectedSegmentIndex == 0 {
                session.resolution = CGSize(width: 3024, height: 4032)
                self.squareLayoutConstraint.priority = .defaultLow
                self.wideLayoutConstraint.priority = .defaultHigh
            } else {
                session.resolution = CGSize(width: 3024, height: 3024)
                self.squareLayoutConstraint.priority = .defaultHigh
                self.wideLayoutConstraint.priority = .defaultLow
            }
        }
    }
}

class PhotoViewController: UIViewController, CKFSessionDelegate, CLLocationManagerDelegate, UITableViewDelegate {
    
    let userid = UIDevice.current.identifierForVendor!.uuidString
    
    let lm = CLLocationManager()
    
    var labelData: [(number: String, img: String, label: String, time: String)] = [("num", "img", "Result", "time")]
    
    @IBOutlet weak var labelTable: UITableView!
    
    private var modelDataHandler: ModelDataHandler? =
      ModelDataHandler(modelFileInfo: MobileNetSSD.modelInfo, labelsFileInfo: MobileNetSSD.labelsInfo)
    private var result: Result?
    
    @IBOutlet weak var squareLayoutConstraint: NSLayoutConstraint!
    @IBOutlet weak var wideLayoutConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var zoomLabel: UILabel!
    @IBOutlet weak var captureButton: UIButton!
    
    func didChangeValue(session: CKFSession, value: Any, key: String) {
        if key == "zoom" {
            self.zoomLabel.text = String(format: "%.1fx", value as! Double)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if let vc = segue.destination as? PhotoSettingsViewController {
            vc.previewView = self.previewView
            self.squareLayoutConstraint.priority = .defaultHigh
            self.wideLayoutConstraint.priority = .defaultLow
            vc.squareLayoutConstraint = self.squareLayoutConstraint
            vc.wideLayoutConstraint = self.wideLayoutConstraint
        } else if let nvc = segue.destination as? UINavigationController, let vc = nvc.children.first as? PhotoPreviewViewController {
            vc.image = sender as? UIImage
        }
    }
    
    @IBOutlet weak var previewView: CKFPreviewView! {
        didSet {
            let session = CKFPhotoSession()
            session.resolution = CGSize(width: 3024, height: 3024)
            session.delegate = self
            
            self.previewView.autorotate = true
            self.previewView.session = session
            self.previewView.previewLayer?.videoGravity = .resizeAspectFill
        }
    }
    
    @IBOutlet weak var panelView: UIVisualEffectView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        guard modelDataHandler != nil else {
          fatalError("Failed to load model")
        }
        self.panelView.transform = CGAffineTransform(translationX: 0, y: self.panelView.frame.height + 5)
        self.panelView.isUserInteractionEnabled = false
        
        // get location
        lm.requestWhenInUseAuthorization()
        
        lm.delegate = self
        lm.startUpdatingLocation()
        
        labelTable.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        labelTable.delegate = self
        labelTable.dataSource = self
        
        
//        // get token
//        let timestamp = NSDate().timeIntervalSince1970*1000000
//        let key = "eL55ndhviEHxGyQZiRSXPRawA46QyYbQywVI-cVQNj8="
//        let key0 = String(timestamp)+"/app"
//        let dats = Data(key.bytes)
//        let hash = dats.sha256()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.previewView.session?.start()
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.previewView.session?.stop()
    }
    
    @IBAction func handleSwipeDown(_ sender: Any) {
        self.panelView.isUserInteractionEnabled = false
        self.captureButton.isUserInteractionEnabled = true
        UIView.animate(withDuration: 0.2) {
            self.panelView.transform = CGAffineTransform(translationX: 0, y: self.panelView.frame.height)
        }
    }
    
    @IBAction func handleSwipeUp(_ sender: Any) {
        self.panelView.isUserInteractionEnabled = true
        self.captureButton.isUserInteractionEnabled = false
        UIView.animate(withDuration: 0.2) {
            self.panelView.transform = CGAffineTransform(translationX: 0, y: 0)
        }
    }
    
    @IBAction func handleCapture(_ sender: UIButton) {
        if let session = self.previewView.session as? CKFPhotoSession {
            self.captureButton.isUserInteractionEnabled = false
            let cameraMediaType = AVMediaType.video
            let cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: cameraMediaType)

            switch cameraAuthorizationStatus {
            case .denied: sendAlert();break
            case .authorized: break
            case .restricted: break

            case .notDetermined: sendAlert();break
            }
            sender.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            session.capture({ (image, _) in
//                print(image as UIImage)
                self.result = self.modelDataHandler?.runModel(onFrame: self.buffer(from: image)!)
                if self.result?.inferences != nil {
                    for i in 0..<(self.result?.inferences.count)!{
                        let res = (self.result?.inferences[i].className)!.replacingOccurrences(of: "\r", with: "", options: .literal, range: nil)
                        let tmp = res
                        self.labelData.append((number: "String", img: "String", label: tmp, time: "String"))
                        if (self.labelData.count>20) {
                            self.labelData = [("num", "img", "Result", "time")]
                        }
                        self.labelTable.reloadData()
                        
                        // send data
                        
                        let userid = String(self.userid)
                        let label = String(res)
                        let location = String(0)
                        var latitude = "0"
                        var longitude = "0"
                        if (CLLocationManager.authorizationStatus() != .denied) {
                            latitude = String((self.lm.location?.coordinate.latitude)!)
                            longitude = String((self.lm.location?.coordinate.longitude)!)
                        }
                        let token = "d2HNsQrIAJLoLFj3KZDpnQhIyh4t1wd2zsyOFG9UPAo"
 
                        let parameters: Parameters = ["userid": userid, "label": label, "location": location, "latitude": latitude, "longitude": longitude, "token": token]
                        
                        let sURL = "http://modovision-api.eastasia.cloudapp.azure.com:8080/WhatTheMask/insert_log"
                        
                        AF.request(sURL, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: nil).validate(statusCode: 200 ..< 299).responseJSON { AFdata in
                            do {
                                guard let jsonObject = try JSONSerialization.jsonObject(with: AFdata.data!) as? [String: Any] else {
                                    print("Error: Cannot convert data to JSON object")
                                    return
                                }
                                guard let prettyJsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted) else {
                                    print("Error: Cannot convert JSON object to Pretty JSON data")
                                    return
                                }
                                guard let prettyPrintedJson = String(data: prettyJsonData, encoding: .utf8) else {
                                    print("Error: Could print JSON in String")
                                    return
                                }
                                
                                print(prettyPrintedJson)
                            } catch {
                                print("Error: Trying to convert JSON data to string")
                                return
                            }
                        }
    
                    }
                }
                sender.backgroundColor = UIColor.lightGray.withAlphaComponent(0.5)
                self.captureButton.isUserInteractionEnabled = true

//                self.performSegue(withIdentifier: "Preview", sender: image)
            }) { (_) in
                //
            }
        }
    }
    
    @IBAction func handleVideo(_ sender: Any) {
//        guard let window = UIApplication.shared.keyWindow else {
//            return
//        }
        
//        let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "Video")
//        UIView.transition(with: window, duration: 0.5, options: .transitionFlipFromLeft, animations: {
//            window.rootViewController = vc
//        }, completion: nil)
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    @objc  func runModel(onPixelBuffer pixelBuffer: CVPixelBuffer) {

      // Run the live camera pixelBuffer through tensorFlow to get the result

      result = self.modelDataHandler?.runModel(onFrame: pixelBuffer)

      guard let displayResult = result else {
        return
      }

      let width = CVPixelBufferGetWidth(pixelBuffer)
      let height = CVPixelBufferGetHeight(pixelBuffer)
    }
    
    func sendAlert() {
        let alertController = UIAlertController (title: "Please open the camera.", message: "Go to Settings?", preferredStyle: .alert)

         let settingsAction = UIAlertAction(title: "Settings", style: .default) { (_) -> Void in

             guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                 return
             }

             if UIApplication.shared.canOpenURL(settingsUrl) {
                 UIApplication.shared.open(settingsUrl, completionHandler: { (success) in
                     print("Settings opened: \(success)") // Prints true
                 })
             }
         }
         alertController.addAction(settingsAction)
         let cancelAction = UIAlertAction(title: "Cancel", style: .default, handler: nil)
         alertController.addAction(cancelAction)

         present(alertController, animated: true, completion: nil)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.first
    }
    
    func buffer(from image: UIImage) -> CVPixelBuffer? {
      let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
      var pixelBuffer : CVPixelBuffer?
      let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.size.width), Int(image.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
      guard (status == kCVReturnSuccess) else {
        return nil
      }

      CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
      let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)

      let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
      let context = CGContext(data: pixelData, width: Int(image.size.width), height: Int(image.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)

      context?.translateBy(x: 0, y: image.size.height)
      context?.scaleBy(x: 1.0, y: -1.0)

      UIGraphicsPushContext(context!)
      image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
      UIGraphicsPopContext()
      CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))

      return pixelBuffer
    }
}

extension PhotoViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        labelData.count
    }
    
    func tableView(_ tableView:UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = labelTable.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        cell.textLabel?.text = labelData[indexPath.row].label
        
//        let number = cell.viewWithTag(0) as? UILabel
//        let img = cell.viewWithTag(1) as? UILabel
//        let label = cell.viewWithTag(2) as? UILabel
//        let time = cell.viewWithTag(3) as? UILabel
//        number?.text = labelData[indexPath.row].number
//        img?.text = labelData[indexPath.row].img
//        label?.text = labelData[indexPath.row].label
//        time?.text = labelData[indexPath.row].time
        return cell
    }
}
