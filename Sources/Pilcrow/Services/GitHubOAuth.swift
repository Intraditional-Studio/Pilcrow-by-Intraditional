import Foundation
import Combine
import AppKit

enum GitHubOAuthConfig {
    /// Public OAuth App client ID. The client secret is intentionally absent:
    /// Device Flow is designed for native apps and never needs it.
    static let clientID = "Ov23liqc360jc7TAHiNf"
    static let scopes = "repo read:user"
}

struct GitHubDeviceCode: Equatable {
    let deviceCode: String
    let userCode: String
    let verificationURI: String
    let verificationURIComplete: String?
    let expiresIn: Int
    let interval: Int

    var approvalURL: URL? {
        if let verificationURIComplete, let url = URL(string: verificationURIComplete) {
            return url
        }
        var components = URLComponents(string: verificationURI)
        components?.queryItems = [URLQueryItem(name: "user_code", value: userCode)]
        return components?.url
    }
}

enum GitHubDevicePollResult {
    case pending
    case slowDown
    case token(String)
}

enum GitHubDeviceFlowError: LocalizedError {
    case expired
    case denied
    case server(String)
    case network(String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .expired:
            return "That code expired. Start a fresh sign-in."
        case .denied:
            return "GitHub access was declined. You can try again whenever you're ready."
        case .server(let message):
            return message
        case .network(let message):
            return "Couldn't reach GitHub. \(message)"
        case .decoding:
            return "GitHub sent a response Pilcrow couldn't read."
        }
    }
}

struct GitHubDeviceFlowService: Sendable {
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 45
        configuration.httpAdditionalHeaders = [
            "Accept": "application/json",
            "User-Agent": "Pilcrow/1.0"
        ]
        session = URLSession(configuration: configuration)
    }

    func requestDeviceCode() async throws -> GitHubDeviceCode {
        let data = try await post(
            url: URL(string: "https://github.com/login/device/code")!,
            fields: [
                URLQueryItem(name: "client_id", value: GitHubOAuthConfig.clientID),
                URLQueryItem(name: "scope", value: GitHubOAuthConfig.scopes)
            ]
        )
        guard let payload = try? JSONDecoder().decode(DeviceCodeDTO.self, from: data) else {
            throw GitHubDeviceFlowError.decoding
        }
        if let error = payload.error {
            throw GitHubDeviceFlowError.server(payload.errorDescription ?? error)
        }
        guard let deviceCode = payload.deviceCode,
              let userCode = payload.userCode,
              let verificationURI = payload.verificationURI else {
            throw GitHubDeviceFlowError.decoding
        }
        return GitHubDeviceCode(
            deviceCode: deviceCode,
            userCode: userCode,
            verificationURI: verificationURI,
            verificationURIComplete: payload.verificationURIComplete,
            expiresIn: payload.expiresIn ?? 900,
            interval: max(1, payload.interval ?? 5)
        )
    }

    func pollAccessToken(deviceCode: String) async throws -> GitHubDevicePollResult {
        let data = try await post(
            url: URL(string: "https://github.com/login/oauth/access_token")!,
            fields: [
                URLQueryItem(name: "client_id", value: GitHubOAuthConfig.clientID),
                URLQueryItem(name: "device_code", value: deviceCode),
                URLQueryItem(name: "grant_type", value: "urn:ietf:params:oauth:grant-type:device_code")
            ]
        )
        guard let payload = try? JSONDecoder().decode(TokenDTO.self, from: data) else {
            throw GitHubDeviceFlowError.decoding
        }
        if let token = payload.accessToken, !token.isEmpty {
            return .token(token)
        }
        switch payload.error {
        case "authorization_pending":
            return .pending
        case "slow_down":
            return .slowDown
        case "expired_token":
            throw GitHubDeviceFlowError.expired
        case "access_denied":
            throw GitHubDeviceFlowError.denied
        default:
            throw GitHubDeviceFlowError.server(payload.errorDescription ?? payload.error ?? "GitHub sign-in failed.")
        }
    }

    private func post(url: URL, fields: [URLQueryItem]) async throws -> Data {
        var components = URLComponents()
        components.queryItems = fields
        guard let body = components.percentEncodedQuery?.data(using: .utf8) else {
            throw GitHubDeviceFlowError.decoding
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw GitHubDeviceFlowError.network(error.localizedDescription)
        } catch {
            throw GitHubDeviceFlowError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw GitHubDeviceFlowError.network("No response from GitHub.")
        }
        if !(200..<300).contains(http.statusCode) {
            if let payload = try? JSONDecoder().decode(DeviceCodeDTO.self, from: data),
               let error = payload.error {
                throw GitHubDeviceFlowError.server(payload.errorDescription ?? error)
            }
            throw GitHubDeviceFlowError.server("GitHub returned \(http.statusCode).")
        }
        return data
    }
}

// MARK: - Device flow UI model

@MainActor
final class GitHubDeviceFlowModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case requesting
        case waiting
        case connecting
        case connected
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var code: GitHubDeviceCode?
    private var task: Task<Void, Never>?
    private let service = GitHubDeviceFlowService()

    var approvalURL: URL? { code?.approvalURL }

    func start(store: AppStore) {
        guard phase == .idle || isFailed else { return }
        task?.cancel()
        store.githubConnectionError = nil
        phase = .requesting
        code = nil
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let code = try await service.requestDeviceCode()
                guard !Task.isCancelled else { return }
                self.code = code
                self.phase = .waiting
                self.openBrowser()
                var interval = max(1, code.interval)
                let deadline = Date().addingTimeInterval(TimeInterval(code.expiresIn))
                while !Task.isCancelled {
                    try await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
                    guard !Task.isCancelled else { return }
                    if Date().timeIntervalSince(deadline) >= 0 {
                        throw GitHubDeviceFlowError.expired
                    }
                    let result = try await service.pollAccessToken(deviceCode: code.deviceCode)
                    switch result {
                    case .pending:
                        continue
                    case .slowDown:
                        interval += 5
                    case .token(let token):
                        self.phase = .connecting
                        let connected = await store.connectGitHubAndWait(token: token)
                        guard !Task.isCancelled else { return }
                        if connected {
                            self.phase = .connected
                        } else {
                            self.phase = .failed(store.githubConnectionError ?? "GitHub connected, but importing repositories failed.")
                        }
                        return
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self.phase = .failed(error.localizedDescription)
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        if phase != .connected { phase = .idle }
        code = nil
    }

    func reset() {
        task?.cancel()
        task = nil
        phase = .idle
        code = nil
    }

    func openBrowser() {
        guard let url = approvalURL else { return }
        NSWorkspace.shared.open(url)
    }

    func copyCode() {
        guard let code else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code.userCode, forType: .string)
    }

    var isBusy: Bool {
        phase == .requesting || phase == .waiting || phase == .connecting
    }

    var isFailed: Bool {
        if case .failed = phase { return true }
        return false
    }

    deinit {
        task?.cancel()
    }
}

// MARK: - DTOs

private struct DeviceCodeDTO: Decodable {
    let deviceCode: String?
    let userCode: String?
    let verificationURI: String?
    let verificationURIComplete: String?
    let expiresIn: Int?
    let interval: Int?
    let error: String?
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationURI = "verification_uri"
        case verificationURIComplete = "verification_uri_complete"
        case expiresIn = "expires_in"
        case interval
        case error
        case errorDescription = "error_description"
    }
}

private struct TokenDTO: Decodable {
    let accessToken: String?
    let tokenType: String?
    let scope: String?
    let error: String?
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
        case error
        case errorDescription = "error_description"
    }
}
