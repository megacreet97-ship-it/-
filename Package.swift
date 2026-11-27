// swift-tools-version:5.9
// Only the platform-independent logic (StreetLog/Logic) is built here, so it can be unit-tested
// with `swift test` on macOS or Linux. The iOS app itself is built from StreetLog.xcodeproj.
import PackageDescription

let package = Package(
    name: "StreetLogLogic",
    platforms: [.macOS(.v13), .iOS(.v17)],
    targets: [
        .target(name: "StreetLogLogic", path: "StreetLog/Logic"),
        .testTarget(name: "StreetLogLogicTests", dependencies: ["StreetLogLogic"], path: "Tests/StreetLogLogicTests"),
    ]
)
