# yolov5 to tflite on iOS
- [x] Swift
- [x] tflite
- [x] CameraKit

# Usage
- tflite example [here](https://github.com/tensorflow/examples/tree/master/lite/examples/object_detection/ios)
- [CameraKit](https://github.com/CameraKit/camerakit-ios)

# Installation:
- Note : The version of TensorFlowLiteSwift in podfile should match with the version of tensorflow when you convert your model used.
```shell
cd yolov5_tflite_demo_ios
pod install
```  
- Install on Xcode
- Put your `yolov5.tflite` model and `label.txt` in `CameraKitDemo/Model` 
- Run  

# Step:
- Take picture and wait a moment  
- It will list what you see