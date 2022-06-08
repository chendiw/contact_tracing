# Choo-choo: A Trustworthy Contact Tracing System
We present Choo-choo, a trustworthy contact tracing system extended from the Apple-Google contact tracing protocol.
Besides the privacy guarantees that come from the original protocol, Choo-choo generates verifiable test results and thus is able to factor in both positive and negative reports to evaluate a user's exposure risk level.

If you want to set up the Choo-choo system, please follow these steps:

### Building servers:
1. In `grpc` directory, run `swift build` to configure dependencies for the servers.
2. To start the central server, run `swift run centralServer`, with optional flags `--host` for host ip address, `--port` for host port and `--clean` to clean up server storage.
3. To start the testing authority server, run `swift run testAuthServer` with the same set of optional flags.

### Building Choo-choo local client on an iOS device:
1. Install Xcode 13.0 or newer.
2. Install CryptoKit package.
3. Build the project as you would do to any xcode project.
4. Make sure your iOS device is bluetooth compatible. Ater the project builds successfully, it will ask for bluetooth permissions. You have to enable bluetooth to use Choo-choo.

### Instructions for client interface:
- Start Service: Enrolls in the Choo-choo system.
- Start Test: Use this when you send in your test specimen to a Choo-choo compatible testing authority.
- Get Test Result: You may manually query for your test result by clicking this. Otherwise, the app queries for your result automatically on a daily basis.
- Report: Report your test result to the central server. Your contacts will be notified (of course, in a way that preserves your privaccy).
- Stop Service: We're sad to see you go, but hopefully our paths will cross again somewhere someday out in the world.
