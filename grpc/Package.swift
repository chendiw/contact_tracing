// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

import class Foundation.ProcessInfo


let packageDependencies: [Package.Dependency] = [
    .package(
        url: "https://github.com/grpc/grpc-swift.git",
        from: "1.0.0"
    ),
    .package(
        url: "https://github.com/apple/swift-protobuf.git",
        from: "1.9.0"
    ),
    .package(
        url: "https://github.com/apple/swift-nio.git",
        from: "2.32.0"
    ),
    .package(
        url: "https://github.com/apple/swift-argument-parser.git",
        from: "1.0.0"
    ),
]

extension Target.Dependency {
    static let testAuthModel: Self = .target(name: "testAuthModel")
    static let centralModel: Self = .target(name: "centralModel")
    static let argumentParser: Self = .product(
        name: "ArgumentParser",
        package: "swift-argument-parser"
    )
    static let grpc: Self = .product(name: "GRPC", package: "grpc-swift")
    static let nio: Self = .product(name: "NIO", package: "swift-nio")
    static let nioCore: Self = .product(name: "NIOCore", package: "swift-nio")
    static let nioPosix: Self = .product(name: "NIOPosix", package: "swift-nio")
    static let protobuf: Self = .product(name: "SwiftProtobuf", package: "swift-protobuf")
}

extension Target {
  static let testAuthModel: Target = .target(
    name: "testAuthModel",
    dependencies: [
      .grpc,
      .nio,
      .protobuf,
    ],
    path: "Model",
    exclude: [
      "testingauth.proto",
      "central.proto",
      "central.grpc.swift",
      "central.pb.swift",
    ]
  )

  static let testAuthServer: Target = .executableTarget(
    name: "testAuthServer",
    dependencies: [
      .grpc,
      .testAuthModel,
      .nioCore,
      .nioPosix,
      .argumentParser,
    ],
    path: "AuthServer"
  )

  static let centralModel: Target = .target(
    name: "centralModel",
    dependencies: [
      .grpc,
      .nio,
      .protobuf,
    ],
    path: "Model",
    exclude: [
      "central.proto",
      "testingauth.proto",
      "testingauth.grpc.swift",
      "testingauth.pb.swift",
    ]
  )

  static let centralServer: Target = .executableTarget(
    name: "centralServer",
    dependencies: [
      .grpc,
      .centralModel,
      .nioCore,
      .nioPosix,
      .argumentParser,
    ],
    path: "CentralServer"
  )
}

extension Product {
  static let testAuthServer: Product = .executable(
    name: "testAuthServer",
    targets: ["testAuthServer"]
  )

  static let testAuthModel: Product = .library(
    name: "testAuthModel",
    targets: ["testAuthModel"]
  )

  static let centralServer: Product = .executable(
    name: "centralServer",
    targets: ["centralServer"]
  )

  static let centralModel: Product = .library(
    name: "centralModel",
    targets: ["centralModel"]
  )
}

let package = Package(
    name: "grpc",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .centralServer,
        .centralModel,
        .testAuthServer,
        .testAuthModel,
    ],
    dependencies: packageDependencies,
    targets: [
        .testAuthModel,
        .testAuthServer,
        .centralModel,
        .centralServer,
    ]
)