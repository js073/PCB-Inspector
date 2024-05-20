# PCB Inspector
PCB Inspector is a native iOS application written in Swift to provide identification of components on a PCB. This application offers features for users to take images of PCBs and find information about the components on them, with support for saving of these identified images. A live overlay feature is also implemented, for live capture and identification. 

## Running the Code
This project requires a device/simulator running iOS 17+, and a Mac with XCode 15+ to build the project. (Older versions may be compatible however haven't been tested). 

Details for building/running an iOS application can be found [here](https://developer.apple.com/documentation/xcode/running-your-app-in-simulator-or-on-a-device). 

All dependencies have been managed with the default Swift package manager and as such should be installed automatically when opening the project in XCode. 

The settings page for the application features a page to allow users to enter their own API credentials for the [Nexar API](https://nexar.com/api) as well as the [Google Programmable Search Engine](https://developers.google.com/custom-search/v1/overview). The application can still be used without these APIs, however. 

## Object Detection Model
The object detection models used in this project are trained using [Ultralytics YOLOv8](https://github.com/ultralytics/ultralytics) with Oriented Bounding Box prediction mode. The dataset used for this training is comprised from one collected for this project and images from [iFixit](https://www.ifixit.com/). 

Two models are used in this project to increase accuracy over all classes. 
- **Large Items Model** can predict Integrated Circuits and Tube Capacitors, and takes an input of 960px. 
- **Small Items Model** predicts surface-mount Resistors and Capacitors, with an input size of 640px. This model works best when used over sub-regions of an input image.   

## Dependencies
- [Alamofire](https://github.com/Alamofire/Alamofire.git) for easier networking in Swift.
- [Swift Collections](github.com/apple/swift-collections.git) for more data structures in Swift. 
- [SwiftImage](https://github.com/koher/swift-image.git) for simple image operations. 
