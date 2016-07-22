# airbitz-core-objc

This repository contains the ObjC bindings to the [airbitz-core][core] library.

## Setup using CocoaPods (no need to clone this repo)

In your xcode project, edit your Podfile and add

    target "nameOfYourProjectHere" do
        pod 'AirbitzCore', :http => "https://developer.airbitz.co/download/airbitz-core-objc-newest.tgz"
    end

Of course you'll need to replace "nameOfYourProjectHere" with your actual Xcode project name.

Close the XCode project and then rerun

    pod install

from the directory with your Podfile.

Reopen the nameOfYourProjectHere.xcworkspace file from Xcode (not the xcproject file).

If you are using React Native, you'll likely get a link error that you are missing some libraries. This is because React Native will overwrite linker flags set by Cocoapods. To fix, go to the project target Build Settings -> Other Linker Flags. Add "$(inherited)" to the linker flags.

And you're done. You should be able to call into AirbitzCore. See documentation below for code samples.

## Using with React Native

Follow the above for installing the CocoaPod into the iOS project of your React Native app.

Clone this repo locally to your computer at the same level as your app repo.

Open the iOS project workspace of your app. Drag the files 

    ReactBridge/ABCReact.c
    ReactBridge/ABCReact.h 
    
and drop them into your React iOS "Libraries" folder in the XCode project.

Create a softlink from the airbitz-core-objc/ReactBridge/abc-react.js file to your React app project main directory. If your project repo is at the same level as airbitz-core-objc, ie.

    .../airbitz-core-obj/
    .../your-app-repo/YourReactApp/

Then run the following from the ```YourReactApp``` directory

    ln -s ../../airbitz-core-objc/ReactBridge/abc-react.js abc-react.js
    
Sample javascript code for using AirbitzCore from ReactNative can be seen in the following repo

https://github.com/Airbitz/airbitz-react-test

See the file ```abc-react-test.js```

## Documentation

https://developer.airbitz.co/objc/


## Building

If you'd like to build the SDK and natively include all the code in your build

First have [airbitz-core][core] cloned locally at the same level as this repository. 

The build process requires several pieces of software to be installed on the
host system:

* autoconf
* automake
* cmake
* git
* libtool
* pkgconfig
* protobuf

To install these on the Mac, please use [Homebrew](http://brew.sh/):

    brew install autoconf automake cmake git libtool pkgconfig protobuf

The 'wget' and 'cmake' that come from MacPorts are known to be broken.
If you are building for iOS or Mac native, you also need a working installation
of the XCode command-line tools.

Then run from the airbitz-core-objc repo:

     ./mkabc

Create or use an Xcode project that is at the same level as this repository.
From your Xcode project edit your Podfile and include the following

    pod 'AirbitzCore', :path => '../airbitz-core-objc/'

[core]: https://github.com/airbitz/airbitz-core
