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
      "testingauth.proto"
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
    path: "Server"
  )

  static let centralModel: Target = .target(
    name: "CentralModel",
    dependencies: [
      .grpc,
      .nio,
      .protobuf,
    ],
    path: "Model",
    exclude: [
      "central.proto",
    ]
  )

  static let centralServer: Target = .executableTarget(
    name: "CentralServer",
    dependencies: [
      .grpc,
      .helloWorldModel,
      .nioCore,
      .nioPosix,
      .argumentParser,
    ],
    path: "Server"
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
    name: "CentralServer",
    targets: ["CentralServer"]
  )

  static let centralModel: Product = .library(
    name: "CentralModel",
    targets: ["CentralModel"]
  )
}

let package = Package(
    name: "grpc",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .testAuthServer,
        .testAuthModel,
    ],
    dependencies: packageDependencies,
    targets: [
        .testAuthModel,
        .testAuthServer,
    ],
)

