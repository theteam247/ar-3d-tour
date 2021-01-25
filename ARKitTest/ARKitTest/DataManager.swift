//
//  Copyright © 2021 Theteam247. All rights reserved.
//

import Foundation
import UIKit

private let kImageQuality: CGFloat = 0.8

class DataManager {
    
    // MARK: - Public
    static let shared = DataManager()
    
    func createFolder(name: String) -> Bool {
        let folderURL = getFolderURL(for: name)
        do {
            if fileManager.fileExists(atPath: folderURL.path) {
                try fileManager.removeItem(at: folderURL)
            }
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
            return true
        } catch {
            print(error.localizedDescription)
            return false
        }
    }
    
    func saveImage(_ image: UIImage, to folder: String) -> String? {
        let folderURL = getFolderURL(for: folder)
        do {
            let fileName = getTimestampString() + ".jpg"
            let fileURL = folderURL.appendingPathComponent(fileName)
            if let imgData = image.jpegData(compressionQuality: kImageQuality) {
                try imgData.write(to: fileURL)
                debugPrint("saved image at: \(fileURL.path)")
                return fileName
            }
        } catch {
            print(error.localizedDescription)
        }
        return nil
    }
        
    func saveImageInfo(_ info: [ImageInfo], to folder: String) {
        let folderURL = getFolderURL(for: folder)
        let fileUrl = folderURL.appendingPathComponent("info.json")
        do {
            let data = try JSONEncoder().encode(info)
            try data.write(to: fileUrl, options: [])
        } catch {
            print(error.localizedDescription)
        }
    }
    
    // MARK: - Private
    private let fileManager = FileManager.default
    lazy private var dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMddHHmmss"
        return df
    }()
    
    private init() {}

    private func getTimestampString() -> String {
        return dateFormatter.string(from: Date())
    }
    
    private func getFolderURL(for folder: String) -> URL {
        guard let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Can't get document directory...")
        }
        return url.appendingPathComponent(folder)
    }
    
    
}
