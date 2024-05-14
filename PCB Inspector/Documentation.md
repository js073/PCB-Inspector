#  Documentation
This file contains documentation and information for the structure of this application. 

**NOTE** : If building from source, place the ML model downloaded from [here]() into the same directory as this file. 

## Organisation
This application is organised into various folders which each contain code for different aspect of the application. 
Inside of most folders there will be a file `*View.swift` which is the SwiftUI view file of the specified section, along with a `*Controller.swift` file which contains the main logic and handling of this section. Most of the application is build in a View-Controller fashion, in order to attempt to segment the view formatting and main logic. Other supplementary files with their specified functions may be in the same folder as well to provide additional functionality as required. 

### HomeViews
The folder contains various views used in the main root view of the application. 
- `PCB_InspectorApp` - root view of application. 
- `HomeView` - main home page, allows user to choose either single-element or multi-element options.
- `HomeViewMulti` - the new and updated home page for Multi Element views. 
- `InformationPage` - outdated information page that was originally going to be included in the application. 
- `InputSelectionView` - after the user selects either single or multi element, they will be prompted to choose the input selection between Camera, Library and Existing (in the case of multi-element). 
- `SettingsView` - provides basic application settings options. 

### GlobalItems
Contains various different definitions that may be used globally throughout the application. 
- `GlobalStorage` - a singleton class that can be used to store various different variables temporarily throughout the application runtime. 
- `Enums` - various different Enums used throughout the application. 
- `Structures` - various Structs used throughout the application. 
- `Constants` - various constants used throughout the application. 
- `Extensions` - provides extensions to various classes for use throughout the application. 

### Camera
Provides the logic required for getting camera input from the user. 
- `CameraDataModel`, `CameraController` - provides the backend logic to get the preview of camera output as well as capture it when the user chooses to capture. 
- `CameraView` - interface to provide camera preview and a preview when the user chooses to take an image. 

### ImageLibrary
Provides logic and view for the user choosing an image from the OS photo library. 

### SingleElement
Provides the logic and view for when the user chooses to identify a single component, uses logic and other functions from the `ComponentIdentification` folder. 

### MultiElement
Provides the logic and view for when the user chooses to identify multiple components, uses logic and other functions from the `ComponentIdentification` folder. 
- `MultiElementView` - main view screen which is a parent of the image view and list view options, allows choice between them. 
- `MultiElementController` - provides the main logic for this section and interfaces with the other classes in the `ComponentIdentification` folder.
- `DataHandler` - Provides the necessary functions and definitions to save an identified PCB using the SwiftData framework.  
- `ComponentsImageView`, `ComponentsListView` - provide the main views both when viewing the identified PCB as an image and as a list of components, respectivley. 
- `ICInfoPopover` - provides the popover view the user will see when selecting an IC to view in more detail.
    - `NoteSection` - provides the note section used in `ICInfoPopover`. 
- `FilterView` - provides the popover for when the user chooses to filter certain component types. 
- `SavingPopover` - provides the popover when the user choose the save the current PCB. 

### ComponentIdentification
Provides the main logic to interface with the ML model and text recognition libraries. 
- `manufacturer_codes`, `manufacturer_list` - text files which provide a list of manufacturers and their IC codes, and a list of possible manufacturers, respectivley. 
- `TextExtraction` - interfaces with the Vision framework to extract text from the given image. 
- `ComponentDetection` - interfaces with the ML model to parse the identified components from the raw model output. 
- `ICInfoExtraction` - takes the raw extracted text and attempts to identify the attributes of the component, using the `APIRequest` file. 
- `APIRequest` - takes a lookup string and attempts to use the [Octopart]() to lookup information. 
- `ImageBinarisation` - takes an image and binarises it, with the option of different binarisation methods.  

### TestViews
Contains many views used in the testing and creation purposes of the application. Code in this folder is not commented or intended to be used in the main running of the application. 

### Utilities 
This folder contains various utilities features that are utilised throughout the application, for example provides the web view used in the application as well as the loading view, and various styling classes for buttons used in the application. 