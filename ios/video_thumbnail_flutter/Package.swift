// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "video_thumbnail_flutter",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "video-thumbnail-flutter", targets: ["video_thumbnail_flutter"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(url: "https://github.com/SDWebImage/libwebp-Xcode.git", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "video_thumbnail_flutter",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "libwebp", package: "libwebp-Xcode"),
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ]
        )
    ]
)
