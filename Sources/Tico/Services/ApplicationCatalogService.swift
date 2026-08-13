import AppKit
import Foundation

@MainActor
final class ApplicationCatalogService {
    private let workspace: NSWorkspace
    private let fileManager: FileManager

    init(
        workspace: NSWorkspace = .shared,
        fileManager: FileManager = .default
    ) {
        self.workspace = workspace
        self.fileManager = fileManager
    }

    func applications() -> [ApplicationChoice] {
        var choices: [String: ApplicationChoice] = [:]

        for application in workspace.runningApplications {
            guard let identifier = application.bundleIdentifier,
                  application.activationPolicy == .regular else {
                continue
            }
            choices[identifier] = ApplicationChoice(
                bundleIdentifier: identifier,
                name: application.localizedName ?? identifier,
                applicationURL: application.bundleURL,
                isRunning: !application.isTerminated
            )
        }

        for directory in applicationDirectories {
            guard let contents = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }
            for url in contents where url.pathExtension == "app" {
                guard let bundle = Bundle(url: url),
                      let identifier = bundle.bundleIdentifier else {
                    continue
                }
                let name = (
                    bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? url.deletingPathExtension().lastPathComponent
                )
                if choices[identifier] == nil {
                    choices[identifier] = ApplicationChoice(
                        bundleIdentifier: identifier,
                        name: name,
                        applicationURL: url,
                        isRunning: false
                    )
                }
            }
        }

        return choices.values.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private var applicationDirectories: [URL] {
        var directories = [URL(fileURLWithPath: "/Applications", isDirectory: true)]
        if let userApplications = fileManager.urls(
            for: .applicationDirectory,
            in: .userDomainMask
        ).first {
            directories.append(userApplications)
        }
        return directories
    }
}
