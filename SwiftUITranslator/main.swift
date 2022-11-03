import Foundation
import RegexBuilder
import OSLog

// MARK: - Frontend

/// 包含要本地化的 SwiftUI 源码的文件夹
/// 比如 `.../your-project/your-project/Views/`
let sourceFilesPath = "The/Path/To/Your/SwiftUI/Views"

/// .strings 文件的输出位置
/// - warning: 要带上文件名！！！类似这里的 `.appending(path: "localizationKeys.string")`
let outputURL = URL(filePath: URL(fileURLWithPath: sourceFilesPath).path(percentEncoded: false)).appending(path: "Localizable.strings")


// MARK: - Backend

let logger = Logger()
var translateString = ""

// Process all files in the dictionary.
handleFolderFiles(url: URL(fileURLWithPath: sourceFilesPath))

// Output the .string file
do {
    if !FileManager.default.fileExists(atPath: outputURL.path()) {
        FileManager.default.createFile(atPath: outputURL.path(), contents: nil)
    }
    try translateString.write(to: outputURL, atomically: true, encoding: .utf8)
    logger.log("Generated successfully.🎉")
} catch {
    logger.error("\(error.localizedDescription)")
}

func findURLs(from url: URL) throws -> [URL] {
    let filesURL = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.includesDirectoriesPostOrder, .skipsPackageDescendants, .skipsHiddenFiles])
    return filesURL
}

func handleFolderFiles(url: URL) {
    do {
        let urls = try findURLs(from: url)
        for url in urls {
            if url.hasDirectoryPath {
                handleFolderFiles(url: url)
            } else if url.pathExtension == "swift" {
                let fileName = url.lastPathComponent
                let strings = extractStrings(from: url)
                if strings.isEmpty == false {
                    createStringPartial(from: fileName, using: strings)
                }
            }
        }
    } catch { logger.error("\(error.localizedDescription)") }
}

func createStringPartial(from fileName: String, using text: [String]) {
    translateString.append("// --------\(fileName)--------\n")
    text.forEach {
        guard $0.isEmpty == false else { return }
        let rowContent = "\"\($0)\" = \"\";\n"
        if translateString.contains(rowContent){
            return
        }
        translateString.append(rowContent)
    }
    translateString.append("\n")
}

func extractStrings(from url: URL) -> [String] {
    // Unwanted matches will start as follows.
    let exceptions = Regex {
        ChoiceOf {
            "@AppStorage"
            "@SceneStorage"
            "print"
            ".keyboardShortcut"
        }
    }
    let regex = Regex {
        Optionally(exceptions)
        "(\""
        Capture {
            ZeroOrMore(.reluctant) {
                NegativeLookahead { "\"" }
                CharacterClass.any
            }
        }
        "\""
    }
    do {
        let rawText = try String(contentsOf: url)
        
        // Filter out the real View files.
        guard rawText.contains("View") && rawText.contains("body") else { return [] }
        
        let matches = rawText.matches(of: regex).filter {
            // Remove the exceptions.
            !String($0.0).starts(with: exceptions)
        }
        
        return matches.map { String($0.1) }
    } catch {
        return []
    }
}
