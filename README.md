# airbitz-core-objc

This repository contains the ObjC bindings to the [airbitz-core][core] library.

## Setup using CocoaPods (no need to clone this repo)

In your xcode project, edit your Podfile and add

    pod 'AirbitzCore', :http => "https://developer.airbitz.co/download/airbitz-core-objc-newest.tgz"

run
    
    pod install
    
And your done!

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
