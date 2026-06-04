import Foundation

public struct AWCommunicationDebugStatus: Equatable {
    public let isSupported: Bool
    public let activationState: String
    public let isReachable: Bool
    public let hasContentPending: Bool
    public let outstandingFileTransferCount: Int
    public let outstandingUserInfoTransferCount: Int
    public let localDeviceId: String
    public let pairedDeviceId: String?
    public let lastMessageAt: Date?
    public let lastFileTransferAt: Date?
    public let lastError: String?

    public init(
        isSupported: Bool,
        activationState: String,
        isReachable: Bool,
        hasContentPending: Bool,
        outstandingFileTransferCount: Int,
        outstandingUserInfoTransferCount: Int,
        localDeviceId: String,
        pairedDeviceId: String?,
        lastMessageAt: Date?,
        lastFileTransferAt: Date?,
        lastError: String?
    ) {
        self.isSupported = isSupported
        self.activationState = activationState
        self.isReachable = isReachable
        self.hasContentPending = hasContentPending
        self.outstandingFileTransferCount = outstandingFileTransferCount
        self.outstandingUserInfoTransferCount = outstandingUserInfoTransferCount
        self.localDeviceId = localDeviceId
        self.pairedDeviceId = pairedDeviceId
        self.lastMessageAt = lastMessageAt
        self.lastFileTransferAt = lastFileTransferAt
        self.lastError = lastError
    }
}
