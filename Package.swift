// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PureLibrary",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PureLibrary",
            targets: ["PureLibrary"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "PureLibrary",
            dependencies: [],
            path: ".",
            exclude: ["tests", "Info.plist"],
            sources: [
                "App",
                "Theme",
                "Models",
                "Engines",
                "Services",
                "ViewModels",
                "Views"
            ]
        )
    ]
)
