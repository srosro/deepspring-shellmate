//
//  SendFeedbackEmail.swift
//  ShellMate
//
//  Created by Daniel Delattre on 16/07/24.
//

import AppKit
import Foundation
import IOKit

class UserSystemProperties {
  static var properties: [String: Any] {
    var p = [String: Any]()

    if let screenSize = NSScreen.main?.frame.size {
      p["screenHeight"] = Int(screenSize.height)
      p["screenWidth"] = Int(screenSize.width)
    }
    p["os"] = "macOS"
    p["osVersion"] = ProcessInfo.processInfo.operatingSystemVersionString

    let infoDict = Bundle.main.infoDictionary ?? [:]
    p["appBuildNumber"] = infoDict["CFBundleVersion"] as? String ?? "Unknown"
    p["appVersionString"] = infoDict["CFBundleShortVersionString"] as? String ?? "Unknown"
    p["mpLib"] = "swift"
    p["manufacturer"] = "Apple"

    // Add additional properties
    p["modelName"] = UserSystemProperties.getSystemInfo(byName: "hw.model")
    p["modelIdentifier"] = UserSystemProperties.getSystemInfo(byName: "hw.machine")

    let coreCount = ProcessInfo.processInfo.processorCount
    p["totalNumberOfCores"] = coreCount

    let memorySize = ProcessInfo.processInfo.physicalMemory
    p["memory"] = ByteCountFormatter.string(fromByteCount: Int64(memorySize), countStyle: .memory)

    if let firmwareVersion = UserSystemProperties.getSystemFirmwareVersion() {
      p["systemFirmwareVersion"] = firmwareVersion
    } else {
      p["systemFirmwareVersion"] = "Unknown"
    }

    if let serialNumber = UserSystemProperties.getSerialNumber() {
      p["serialNumber"] = serialNumber
    }

    p["hardwareUUID"] = UserSystemProperties.getIOPlatformUUID()

    return p
  }

  class func deviceModel() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    let modelCode = withUnsafePointer(to: &systemInfo.machine) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) {
        String(cString: $0)
      }
    }
    return modelCode
  }

  class func getSystemInfo(byName name: String) -> String {
    var size = 0
    sysctlbyname(name, nil, &size, nil, 0)
    var result = [CChar](repeating: 0, count: size)
    sysctlbyname(name, &result, &size, nil, 0)
    return result.withUnsafeBufferPointer {
      String(cString: $0.baseAddress!)
    }
  }

  class func getSystemFirmwareVersion() -> String? {
    var size: size_t = 0
    let result = sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
    guard result == 0 else { return nil }
    var answer = [CChar](repeating: 0, count: size)
    let result2 = sysctlbyname("machdep.cpu.brand_string", &answer, &size, nil, 0)
    guard result2 == 0 else { return nil }
    return String(cString: answer)
  }

  class func getSerialNumber() -> String? {
    var serialNumber: String?
    let platformExpert = IOServiceGetMatchingService(
      kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
    if let key = kIOPlatformSerialNumberKey as String? {
      serialNumber =
        IORegistryEntryCreateCFProperty(platformExpert, key as CFString, kCFAllocatorDefault, 0)
        .takeUnretainedValue() as? String
    }
    IOObjectRelease(platformExpert)
    return serialNumber
  }

  class func getIOPlatformUUID() -> String {
    var uuid: String?
    let platformExpert = IOServiceGetMatchingService(
      kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
    if let key = kIOPlatformUUIDKey as String? {
      uuid =
        IORegistryEntryCreateCFProperty(platformExpert, key as CFString, kCFAllocatorDefault, 0)
        .takeUnretainedValue() as? String
    }
    IOObjectRelease(platformExpert)
    return uuid ?? "Unknown"
  }
}

func createFeedbackEmailURL() -> URL? {
  let email = "feedback@deepspring.ai"
  let subject = "User feedback - Shellmate"

  // Collect detailed information using UserSystemProperties
  var userProperties = UserSystemProperties.properties

  // Remove duplicates
  userProperties.removeValue(forKey: "model")

  // Sort properties by name
  let sortedProperties = userProperties.sorted(by: { $0.key < $1.key })

  // Create properties string
  var propertiesString = ""
  for (key, value) in sortedProperties {
    propertiesString += "\(key): \(value)\n"
  }

  let body = """
    [Please describe the issue or provide your feedback here]



    ----------------------------------------
    Please do not write below this line.
    ----------------------------------------

    \(propertiesString)
    """

  let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
  let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

  let emailURLString = "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)"
  return URL(string: emailURLString)
}

func sendFeedbackEmail() {
  guard let url = createFeedbackEmailURL() else {
    print("Unable to create email URL")
    return
  }
  NSWorkspace.shared.open(url)
}
