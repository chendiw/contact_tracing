// swift-tools-version: 5.6
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
    static let helloWorldModel: Self = .target(name: "HelloWorldModel")
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
  static let helloWorldModel: Target = .target(
    name: "HelloWorldModel",
    dependencies: [
      .grpc,
      .nio,
      .protobuf,
    ],
    path: "Model",
    exclude: [
      "helloworld.proto",
    ]
  )

  static let helloWorldServer: Target = .executableTarget(
    name: "HelloWorldServer",
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
  static let helloWorldServer: Product = .executable(
    name: "server",
    targets: ["HelloWorldServer"]
  )

  static let helloWorldModel: Product = .library(
    name: "model",
    targets: ["HelloWorldModel"]
  )
}

let package = Package(
    name: "our_grpc",
    products: [
        .helloWorldServer,
        .helloWorldModel,
    ],
    dependencies: packageDependencies,
    targets: [
        .helloWorldModel,
        .helloWorldServer,
    ]
)

