//
//  OPCLIRunner.swift
//  KeychainTo1Password
//
//  Shared runner for the `op` CLI. Uses 1Password desktop app integration
//  for authentication (biometric unlock) — no service account token needed.
//  Requires: `op` CLI installed + 1Password desktop integration enabled.
//
//  Created by Jordan Koch on 5/14/26.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

final class OPCLIRunner: @unchecked Sendable {

    enum CLIError: LocalizedError {
        case notFound
        case authFailed(String)
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .notFound:
                return "1Password CLI (op) not found. Install: brew install 1password-cli"
            case .authFailed(let msg):
                return "1Password auth failed. Enable CLI integration in 1Password → Settings → Developer. (\(msg))"
            case .commandFailed(let msg):
                return msg
            }
        }
    }

    private let opPath: String

    init() throws {
        let paths = [
            "/opt/homebrew/bin/op",
            "/usr/local/bin/op",
            "/usr/bin/op"
        ]
        guard let found = paths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            throw CLIError.notFound
        }
        opPath = found
    }

    func verifyAuth() async throws {
        let (_, stderr, status) = await run(["whoami"])
        guard status == 0 else {
            throw CLIError.authFailed(stderr)
        }
    }

    func run(_ arguments: [String]) async -> (stdout: String, stderr: String, status: Int32) {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: opPath)
            process.arguments = arguments
            process.environment = ProcessInfo.processInfo.environment

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            do {
                try process.run()
                process.waitUntilExit()

                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                continuation.resume(returning: (stdout, stderr, process.terminationStatus))
            } catch {
                continuation.resume(returning: ("", error.localizedDescription, -1))
            }
        }
    }

    func runJSON<T: Decodable>(_ arguments: [String], as type: T.Type) async throws -> T {
        let (stdout, stderr, status) = await run(arguments)
        guard status == 0 else {
            throw CLIError.commandFailed(stderr.isEmpty ? "Command failed with status \(status)" : stderr)
        }
        guard let data = stdout.data(using: .utf8), !data.isEmpty else {
            throw CLIError.commandFailed("Empty response from op CLI")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
