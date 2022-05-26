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
    path: "contact_tracing/Model",
    exclude: [
      "helloworld.proto",
    ]
  )

  static let helloWorldClient: Target = .executableTarget(
    name: "HelloWorldClient",
    dependencies: [
      .grpc,
      .helloWorldModel,
      .nioCore,
      .nioPosix,
      .argumentParser,
    ],
    path: "contact_tracing/Client"
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
    path: "contact_tracing/Server"
  )
}

let package = Package(
    name: "ContactTracing",
    /*products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "ContactTracing",
            targets: ["ContactTracing"]),
    ],*/
    dependencies: packageDependencies,
    targets: [
        .helloWorldModel,
        .helloWorldClient,
        .helloWorldServer,
    ]
)

