import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ConversionError: LocalizedError {
    case unsupportedFormat
    case sourceFileMissing
    case sourceFileNotReadable
    case unableToReadImage
    case outputDirectoryNotWritable
    case unableToCreateDestination
    case conversionFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "This image format is not supported."
        case .sourceFileMissing:
            return "The dragged file no longer exists."
        case .sourceFileNotReadable:
            return "Clementine cannot read the dragged file. Check its permissions and try again."
        case .unableToReadImage:
            return "Unable to read the image."
        case .outputDirectoryNotWritable:
            return "Clementine cannot save beside the original file."
        case .unableToCreateDestination:
            return "Unable to create the output file."
        case .conversionFailed:
            return "The image conversion failed."
        }
    }
}

enum ImageFormat: String, CaseIterable, Identifiable {
    case png = "PNG"
    case jpeg = "JPEG"
    case heic = "HEIC"
    case pdf = "PDF"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .png: "png"
        case .jpeg: "jpg"
        case .heic: "heic"
        case .pdf: "pdf"
        }
    }

    var type: UTType {
        switch self {
        case .png: .png
        case .jpeg: .jpeg
        case .heic: .heic
        case .pdf: .pdf
        }
    }
}

struct FileConverter {
    func convertImage(
        at inputURL: URL,
        to format: ImageFormat
    ) throws -> URL {
        let fileManager = FileManager.default
        let accessingSecurityScope = inputURL.startAccessingSecurityScopedResource()
        defer {
            if accessingSecurityScope {
                inputURL.stopAccessingSecurityScopedResource()
            }
        }

        guard fileManager.fileExists(atPath: inputURL.path) else {
            throw ConversionError.sourceFileMissing
        }

        guard fileManager.isReadableFile(atPath: inputURL.path) else {
            throw ConversionError.sourceFileNotReadable
        }

        let supportedExtensions = [
            "png", "jpg", "jpeg", "heic", "tif", "tiff"
        ]
        guard supportedExtensions.contains(inputURL.pathExtension.lowercased()) else {
            throw ConversionError.unsupportedFormat
        }

        let directory = inputURL.deletingLastPathComponent()
        guard fileManager.isWritableFile(atPath: directory.path) else {
            throw ConversionError.outputDirectoryNotWritable
        }

        guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil) else {
            throw ConversionError.unableToReadImage
        }

        let outputURL = uniqueOutputURL(for: inputURL, extension: format.fileExtension)

        if format == .pdf {
            return try convertImageSourceToPDF(source, outputURL: outputURL)
        }

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            format.type.identifier as CFString,
            CGImageSourceGetCount(source),
            nil
        ) else {
            throw ConversionError.unableToCreateDestination
        }

        for index in 0..<CGImageSourceGetCount(source) {
            CGImageDestinationAddImageFromSource(destination, source, index, nil)
        }

        guard CGImageDestinationFinalize(destination) else {
            try? fileManager.removeItem(at: outputURL)
            throw ConversionError.conversionFailed
        }

        return outputURL
    }

    private func convertImageSourceToPDF(
        _ source: CGImageSource,
        outputURL: URL
    ) throws -> URL {
        guard let firstImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ConversionError.unableToReadImage
        }

        var mediaBox = CGRect(
            x: 0,
            y: 0,
            width: CGFloat(firstImage.width),
            height: CGFloat(firstImage.height)
        )
        guard let context = CGContext(outputURL as CFURL, mediaBox: &mediaBox, nil) else {
            throw ConversionError.unableToCreateDestination
        }

        for index in 0..<CGImageSourceGetCount(source) {
            guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else {
                context.closePDF()
                try? FileManager.default.removeItem(at: outputURL)
                throw ConversionError.conversionFailed
            }

            context.beginPDFPage(nil)
            context.draw(image, in: mediaBox)
            context.endPDFPage()
        }

        context.closePDF()
        return outputURL
    }

    private func uniqueOutputURL(
        for inputURL: URL,
        extension fileExtension: String
    ) -> URL {
        let directory = inputURL.deletingLastPathComponent()
        let filename = inputURL.deletingPathExtension().lastPathComponent
        var candidate = directory
            .appendingPathComponent(filename)
            .appendingPathExtension(fileExtension)
        var counter = 1

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory
                .appendingPathComponent("\(filename)-\(counter)")
                .appendingPathExtension(fileExtension)
            counter += 1
        }

        return candidate
    }
}
