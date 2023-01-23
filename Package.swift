// swift-tools-version:5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RicohLiveView",
    platforms: [
        .iOS(.v11),
        .macOS(.v11)
    ],
    products: [
        .library(name: "RicohLiveView", type: .static, targets: [ "RicohLiveView" ])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "RicohLiveView",
            dependencies: [ .target(name: "RicohLiveViewStream") ]
        ),
        .target(
            name: "RicohLiveViewStream",
            publicHeadersPath: "Public"
        )
    ]
)
