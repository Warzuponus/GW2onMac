//
//  HTTPDownload.swift
//  GW2Kit
//
//  GW2onMac — Guild Wars 2 launcher for Apple Silicon Macs.
//

import Foundation

public enum HTTPDownloadError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case zeroBytes

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The download server returned an invalid response."
        case .httpStatus(let code):
            return "Download failed with HTTP status \(code)."
        case .zeroBytes:
            return "The downloaded file is empty."
        }
    }
}

/// Downloads a remote file with optional progress reporting (0.0–1.0).
public enum HTTPDownload {
    public static func download(
        from sourceURL: URL,
        to destinationURL: URL,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let handler = DownloadHandler(
                destinationURL: destinationURL,
                progress: progress
            ) { result in
                continuation.resume(with: result)
            }

            let session = URLSession(
                configuration: .ephemeral,
                delegate: handler,
                delegateQueue: nil
            )
            handler.session = session
            session.downloadTask(with: sourceURL).resume()
        }
    }
}

private final class DownloadHandler: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let destinationURL: URL
    private let progress: (@Sendable (Double) -> Void)?
    private let completion: (@Sendable (Result<Void, Error>) -> Void)
    private var finished = false

    var session: URLSession?

    init(
        destinationURL: URL,
        progress: (@Sendable (Double) -> Void)?,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        self.destinationURL = destinationURL
        self.progress = progress
        self.completion = completion
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        do {
            if let http = downloadTask.response as? HTTPURLResponse,
               !(200 ... 299).contains(http.statusCode) {
                throw HTTPDownloadError.httpStatus(http.statusCode)
            }

            let attrs = try FileManager.default.attributesOfItem(atPath: location.path)
            let size = attrs[.size] as? Int64 ?? 0
            guard size > 0 else {
                throw HTTPDownloadError.zeroBytes
            }

            let directory = destinationURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: location, to: destinationURL)

            progress?(1.0)
            finish(with: .success(()))
        } catch {
            finish(with: .failure(error))
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        progress?(min(max(fraction, 0), 1))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            finish(with: .failure(error))
        }
    }

    private func finish(with result: Result<Void, Error>) {
        guard !finished else { return }
        finished = true
        completion(result)
        session?.finishTasksAndInvalidate()
    }
}
