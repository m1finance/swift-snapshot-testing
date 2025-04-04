import XCTest

/// Enhances failure messages with a command line diff tool expression that can be copied and pasted into a terminal.
///
///     diffTool = "ksdiff"
public var diffTool: String? = nil

/// Whether or not to record all new references.
public var isRecording = false

/// Whether or not to record all new references.
/// Due to a name clash in Xcode 12, this has been renamed to `isRecording`.
@available(*, deprecated, renamed: "isRecording")
public var record: Bool {
  get { isRecording }
  set { isRecording = newValue }
}

/// Asserts that a given value matches a reference on disk.
///
/// - Parameters:
///   - value: A value to compare against a reference.
///   - snapshotting: A strategy for serializing, deserializing, and comparing values.
///   - name: An optional description of the snapshot.
///   - recording: Whether or not to record a new reference.
///   - timeout: The amount of time a snapshot must be generated in.
///   - file: The file in which failure occurred. Defaults to the file name of the test case in which this function was called.
///   - testName: The name of the test in which failure occurred. Defaults to the function name of the test case in which this function was called.
///   - line: The line number on which failure occurred. Defaults to the line number on which this function was called.
public func assertSnapshot<Value, Format>(
  matching value: @autoclosure () throws -> Value,
  as snapshotting: Snapshotting<Value, Format>,
  named name: String? = nil,
  record recording: Bool = false,
  timeout: TimeInterval = 5,
  file: StaticString = #file,
  testName: String = #function,
  line: UInt = #line
  ) {

  let failure = verifySnapshot(
    matching: try value(),
    as: snapshotting,
    named: name,
    record: recording,
    timeout: timeout,
    file: file,
    testName: testName,
    line: line
  )
  guard let message = failure else { return }
  XCTFail(message, file: file, line: line)
}

/// Asserts that a given value matches references on disk.
///
/// - Parameters:
///   - value: A value to compare against a reference.
///   - strategies: A dictionary of names and strategies for serializing, deserializing, and comparing values.
///   - recording: Whether or not to record a new reference.
///   - timeout: The amount of time a snapshot must be generated in.
///   - file: The file in which failure occurred. Defaults to the file name of the test case in which this function was called.
///   - testName: The name of the test in which failure occurred. Defaults to the function name of the test case in which this function was called.
///   - line: The line number on which failure occurred. Defaults to the line number on which this function was called.
public func assertSnapshots<Value, Format>(
  matching value: @autoclosure () throws -> Value,
  as strategies: [String: Snapshotting<Value, Format>],
  record recording: Bool = false,
  timeout: TimeInterval = 5,
  file: StaticString = #file,
  testName: String = #function,
  line: UInt = #line
  ) {

  try? strategies.forEach { name, strategy in
    assertSnapshot(
      matching: try value(),
      as: strategy,
      named: name,
      record: recording,
      timeout: timeout,
      file: file,
      testName: testName,
      line: line
    )
  }
}

/// Asserts that a given value matches references on disk.
///
/// - Parameters:
///   - value: A value to compare against a reference.
///   - strategies: An array of strategies for serializing, deserializing, and comparing values.
///   - recording: Whether or not to record a new reference.
///   - timeout: The amount of time a snapshot must be generated in.
///   - file: The file in which failure occurred. Defaults to the file name of the test case in which this function was called.
///   - testName: The name of the test in which failure occurred. Defaults to the function name of the test case in which this function was called.
///   - line: The line number on which failure occurred. Defaults to the line number on which this function was called.
public func assertSnapshots<Value, Format>(
  matching value: @autoclosure () throws -> Value,
  as strategies: [Snapshotting<Value, Format>],
  record recording: Bool = false,
  timeout: TimeInterval = 5,
  file: StaticString = #file,
  testName: String = #function,
  line: UInt = #line
  ) {

  try? strategies.forEach { strategy in
    assertSnapshot(
      matching: try value(),
      as: strategy,
      record: recording,
      timeout: timeout,
      file: file,
      testName: testName,
      line: line
    )
  }
}

/// Verifies that a given value matches a reference on disk.
///
/// Third party snapshot assert helpers can be built on top of this function. Simply invoke `verifySnapshot` with your own arguments, and then invoke `XCTFail` with the string returned if it is non-`nil`. For example, if you want the snapshot directory to be determined by an environment variable, you can create your own assert helper like so:
///
///     public func myAssertSnapshot<Value, Format>(
///       matching value: @autoclosure () throws -> Value,
///       as snapshotting: Snapshotting<Value, Format>,
///       named name: String? = nil,
///       record recording: Bool = false,
///       timeout: TimeInterval = 5,
///       file: StaticString = #file,
///       testName: String = #function,
///       line: UInt = #line
///       ) {
///
///         let snapshotDirectory = ProcessInfo.processInfo.environment["SNAPSHOT_REFERENCE_DIR"]! + "/" + #file
///         let failure = verifySnapshot(
///           matching: value,
///           as: snapshotting,
///           named: name,
///           record: recording,
///           snapshotDirectory: snapshotDirectory,
///           timeout: timeout,
///           file: file,
///           testName: testName
///         )
///         guard let message = failure else { return }
///         XCTFail(message, file: file, line: line)
///     }
///
/// - Parameters:
///   - value: A value to compare against a reference.
///   - snapshotting: A strategy for serializing, deserializing, and comparing values.
///   - name: An optional description of the snapshot.
///   - recording: Whether or not to record a new reference.
///   - snapshotDirectory: Optional directory to save snapshots. By default snapshots will be saved in a directory with the same name as the test file, and that directory will sit inside a directory `__Snapshots__` that sits next to your test file.
///   - timeout: The amount of time a snapshot must be generated in.
///   - file: The file in which failure occurred. Defaults to the file name of the test case in which this function was called.
///   - testName: The name of the test in which failure occurred. Defaults to the function name of the test case in which this function was called.
///   - line: The line number on which failure occurred. Defaults to the line number on which this function was called.
/// - Returns: A failure message or, if the value matches, nil.
public func verifySnapshot<Value, Format>(
  matching value: @autoclosure () throws -> Value,
  as snapshotting: Snapshotting<Value, Format>,
  named name: String? = nil,
  record recording: Bool = false,
  snapshotDirectory: String? = nil,
  timeout: TimeInterval = 5,
  file: StaticString = #file,
  testName: String = #function,
  line: UInt = #line
  )
  -> String? {

    CleanCounterBetweenTestCases.registerIfNeeded()
    let recording = recording || isRecording

    do {
      let fileUrl = URL(fileURLWithPath: "\(file)", isDirectory: false)
      let fileName = fileUrl.deletingPathExtension().lastPathComponent

      let snapshotDirectoryUrl = snapshotDirectory.map { URL(fileURLWithPath: $0, isDirectory: true) }
        ?? fileUrl
          .deletingLastPathComponent()
          .appendingPathComponent("__Snapshots__")
          .appendingPathComponent(fileName)

      let identifier: String
      if let name = name {
        identifier = sanitizePathComponent(name)
      } else {
        let counter = counterQueue.sync { () -> Int in
          let key = snapshotDirectoryUrl.appendingPathComponent(testName)
          counterMap[key, default: 0] += 1
          return counterMap[key]!
        }
        identifier = String(counter)
      }

      let testName = sanitizePathComponent(testName)
      let snapshotFileUrl = snapshotDirectoryUrl
        .appendingPathComponent("\(testName).\(identifier)")
        .appendingPathExtension(snapshotting.pathExtension ?? "")
      let fileManager = FileManager.default
      try fileManager.createDirectory(at: snapshotDirectoryUrl, withIntermediateDirectories: true)

      let tookSnapshot = XCTestExpectation(description: "Took snapshot")
      var optionalDiffable: Format?
      snapshotting.snapshot(try value()).run { b in
        optionalDiffable = b
        tookSnapshot.fulfill()
      }
      let result = XCTWaiter.wait(for: [tookSnapshot], timeout: timeout)
      switch result {
      case .completed:
        break
      case .timedOut:
        return """
          Exceeded timeout of \(timeout) seconds waiting for snapshot.

          This can happen when an asynchronously rendered view (like a web view) has not loaded. \
          Ensure that every subview of the view hierarchy has loaded to avoid timeouts, or, if a \
          timeout is unavoidable, consider setting the "timeout" parameter of "assertSnapshot" to \
          a higher value.
          """
      case .incorrectOrder, .invertedFulfillment, .interrupted:
        return "Couldn't snapshot value"
      @unknown default:
        return "Couldn't snapshot value"
      }

      guard var diffable = optionalDiffable else {
        return "Couldn't snapshot value"
      }

      let artifactsUrl = URL(
        fileURLWithPath: ProcessInfo.processInfo.environment["SNAPSHOT_ARTIFACTS"] ?? NSTemporaryDirectory(), isDirectory: true
      )

      guard !recording, fileManager.fileExists(atPath: snapshotFileUrl.path) else {
        let snapshotData = snapshotting.diffing.toData(diffable)
        try snapshotData.write(to: snapshotFileUrl)
        #if !os(Linux) && !os(Windows)
        if ProcessInfo.processInfo.environment.keys.contains("__XCODE_BUILT_PRODUCTS_DIR_PATHS") {
          XCTContext.runActivity(named: "Attached Recorded Snapshot") { activity in
            let attachment = XCTAttachment(contentsOfFile: snapshotFileUrl)
            activity.add(attachment)
          }
        }
        #endif

        let artifactsSubUrl = artifactsUrl.appendingPathComponent(fileName).appendingPathComponent(snapshotFileUrl.lastPathComponent).deletingPathExtension()
        let writeArtifactUrl = artifactsSubUrl.appendingPathComponent(snapshotFileUrl.lastPathComponent)
        try fileManager.createDirectory(at: artifactsSubUrl, withIntermediateDirectories: true)
        try snapshotData.write(to: writeArtifactUrl)

        return recording
          ? """
            Record mode is on. Turn record mode off and re-run "\(testName)" to test against the newly-recorded snapshot.

            open "\(snapshotFileUrl.absoluteString)"

            Recorded snapshot: …
            """
          : """
            No reference was found on disk. Automatically recorded snapshot: …

            open "\(snapshotFileUrl.path)"

            Re-run "\(testName)" to test against the newly-recorded snapshot.
            """
      }

      let data = try Data(contentsOf: snapshotFileUrl)
      let reference = snapshotting.diffing.fromData(data)

      #if os(iOS) || os(tvOS)
      // If the image generation fails for the diffable part and the reference was empty, use the reference
      if let localDiff = diffable as? UIImage,
         let refImage = reference as? UIImage,
         localDiff.size == .zero && refImage.size == .zero {
        diffable = reference
      }
      #endif

      // Always perform diff, and return early on success!
      let artifactDiff = snapshotting.diffing.artifactDiff(reference, diffable)
      let attachmentDiff = snapshotting.diffing.diff(reference, diffable)

      guard artifactDiff != nil || attachmentDiff != nil else {
        return nil
      }

      var failedSnapshotFileUrl: URL!
      var failureMessage: String!

      if let (failure, artifacts) = artifactDiff {
        let testDirectoryName: String = "\(testName).\(identifier)"
        let artifactsSubUrl = artifactsUrl.appendingPathComponent(fileName).appendingPathComponent(testDirectoryName)
        failureMessage = failure
        failedSnapshotFileUrl = try createArtifacts(snapshotting: snapshotting,
                                                        artifacts: artifacts,
                                                        artifactsSubUrl: artifactsSubUrl,
                                                        testDirectoryName: testDirectoryName)

      } else if let (failure, attachments) = attachmentDiff {
        let artifactsSubUrl = artifactsUrl.appendingPathComponent(fileName)
        failureMessage = failure
        failedSnapshotFileUrl = try createArtifacts(snapshotting: snapshotting,
                                                        diffable: diffable,
                                                        attachments: attachments,
                                                        artifactsSubUrl: artifactsSubUrl,
                                                        snapshotFileUrl: snapshotFileUrl)
      }

      let diffMessage = diffTool
        .map { "\($0) \"\(snapshotFileUrl.path)\" \"\(failedSnapshotFileUrl.path)\"" }
        ?? """
        @\(minus)
        "\(snapshotFileUrl.absoluteString)"
        @\(plus)
        "\(failedSnapshotFileUrl.absoluteString)"

        To configure output for a custom diff tool, like Kaleidoscope:

            SnapshotTesting.diffTool = "ksdiff"
        """


      if failureMessage == nil {
        failureMessage = "Snapshot does not match reference."
      }

      return """
      \(failureMessage!)

      \(diffMessage)

      \(failureMessage.trimmingCharacters(in: .whitespacesAndNewlines))
      """
    } catch {
      return error.localizedDescription
    }
}

/// Create artifacts from `SnapshotArtifact`s and write them to disk.
private func createArtifacts<Value, Format>(
  snapshotting: Snapshotting<Value, Format>,
  artifacts: [SnapshotArtifact],
  artifactsSubUrl: URL,
  testDirectoryName: String) throws -> URL {

  if !artifacts.isEmpty {
    #if !os(Linux)
    if ProcessInfo.processInfo.environment.keys.contains("__XCODE_BUILT_PRODUCTS_DIR_PATHS") {
      XCTContext.runActivity(named: "Attached Failure Diff") { activity in
        artifacts.forEach {
          let attachment = XCTAttachment(
            uniformTypeIdentifier: $0.uniformTypeIdentifier,
            name: $0.artifactType.rawValue,
            payload: $0.data
          )
          activity.add(attachment)
        }
      }
    }
    #endif
  }

  try FileManager.default.createDirectory(at: artifactsSubUrl, withIntermediateDirectories: true)

  for artifact in artifacts {
    let artifactFileName = testDirectoryName + "_" + artifact.artifactType.rawValue
    let artifactFileUrl = artifactsSubUrl.appendingPathComponent(artifactFileName)
      .appendingPathExtension(snapshotting.pathExtension ?? "")
    try artifact.data.write(to: artifactFileUrl)
  }

  return artifactsSubUrl
    .appendingPathComponent(testDirectoryName + "_" + SnapshotArtifact.ArtifactType.failure.rawValue)
    .appendingPathExtension(snapshotting.pathExtension ?? "")
}

/// Create artifacts from `XCTAttachment`s and write them to disk.
private func createArtifacts<Value, Format>(
  snapshotting: Snapshotting<Value, Format>,
  diffable: Format,
  attachments: [XCTAttachment],
  artifactsSubUrl: URL,
  snapshotFileUrl: URL) throws -> URL {

  if !attachments.isEmpty {
    #if !os(Linux)
    if ProcessInfo.processInfo.environment.keys.contains("__XCODE_BUILT_PRODUCTS_DIR_PATHS") {
      XCTContext.runActivity(named: "Attached Failure Diff") { activity in
        attachments.forEach {
          activity.add($0)
        }
      }
    }
    #endif
  }

  try FileManager.default.createDirectory(at: artifactsSubUrl, withIntermediateDirectories: true)
  let failedSnapshotFileUrl = artifactsSubUrl.appendingPathComponent(snapshotFileUrl.lastPathComponent)
  try snapshotting.diffing.toData(diffable).write(to: failedSnapshotFileUrl)
  return failedSnapshotFileUrl
}

// MARK: - Private

private let counterQueue = DispatchQueue(label: "co.pointfree.SnapshotTesting.counter")
private var counterMap: [URL: Int] = [:]

func sanitizePathComponent(_ string: String) -> String {
  return string
    .replacingOccurrences(of: "\\W+", with: "-", options: .regularExpression)
    .replacingOccurrences(of: "^-|-$", with: "", options: .regularExpression)
}

// We need to clean counter between tests executions in order to support test-iterations.
private class CleanCounterBetweenTestCases: NSObject, XCTestObservation {
    private static var registered = false
    private static var registerQueue = DispatchQueue(label: "co.pointfree.SnapshotTesting.testObserver")

    static func registerIfNeeded() {
      registerQueue.sync {
        if !registered {
          registered = true
          XCTestObservationCenter.shared.addTestObserver(CleanCounterBetweenTestCases())
        }
      }
    }

    func testCaseDidFinish(_ testCase: XCTestCase) {
      counterQueue.sync {
        counterMap = [:]
      }
    }
}
