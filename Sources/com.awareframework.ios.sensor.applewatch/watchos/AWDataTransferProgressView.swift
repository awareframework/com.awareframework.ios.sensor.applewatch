//
//  AWDataTransferProgressView.swift
//  com.awareframework.ios.sensor.applewatch
//
//  Created by Yuuki Nishiyama on 2026/06/03.
//

#if os(watchOS)

import SwiftUI

// MARK: - Main progress view

/// A SwiftUI view that visualises an ongoing `AWDataTransferManager` transfer session.
/// Embed it anywhere in the watch app's view hierarchy and pass the shared manager,
/// or a custom instance.
///
/// ```swift
/// AWDataTransferProgressView()           // uses .shared
/// AWDataTransferProgressView(manager: myManager)
/// ```
public struct AWDataTransferProgressView: View {

    @ObservedObject public var manager: AWDataTransferManager

    public init(manager: AWDataTransferManager = .shared) {
        self.manager = manager
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {

                // ── State label ──────────────────────────────────────────────
                HStack {
                    stateIcon
                    Text(verbatim: manager.state.displayText)
                        .font(.headline)
                        .lineLimit(2)
                }

                // ── Overall progress ─────────────────────────────────────────
                VStack(alignment: .leading, spacing: 3) {
                    ProgressView(value: manager.overallProgress)
                        .progressViewStyle(
                            LinearProgressViewStyle(tint: progressTint)
                        )
                        .animation(.easeInOut(duration: 0.4), value: manager.overallProgress)

                    HStack {
                        Text(verbatim: "\(Int(manager.overallProgress * 100)) %")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        if manager.totalChunks > 0 {
                            Text(verbatim: "\(manager.completedChunks) / \(manager.totalChunks) チャンク")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // ── Individual chunk transfers ────────────────────────────────
                if !manager.transfers.isEmpty {
                    Divider()
                    ForEach(manager.transfers) { item in
                        AWTransferItemRow(item: item)
                    }
                }

                // ── Error message ────────────────────────────────────────────
                if let error = manager.lastError {
                    Divider()
                    Text(verbatim: error)
                        .font(.caption2)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.leading)
                }

                // ── Cancel button ────────────────────────────────────────────
                if manager.state.isActive {
                    Button(role: .destructive) {
                        manager.cancel()
                    } label: {
                        Label("キャンセル", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
        }
        .navigationTitle("データ転送")
    }

    // MARK: State-specific decorations

    private var progressTint: Color {
        switch manager.state {
        case .completed: return .green
        case .failed:    return .red
        default:         return .blue
        }
    }

    @ViewBuilder
    private var stateIcon: some View {
        switch manager.state {
        case .idle:
            Image(systemName: "arrow.up.arrow.down.circle")
                .foregroundColor(.secondary)
        case .preparing:
            if #available(watchOS 10.0, *) {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.orange)
                    .symbolEffect(.pulse)
            } else {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.orange)
            }
        case .transferring:
            if #available(watchOS 10.0, *) {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(.blue)
                    .symbolEffect(.pulse)
            } else {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(.blue)
            }
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
        }
    }
}

// MARK: - Individual chunk row

private struct AWTransferItemRow: View {
    let item: AWTransferItem

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: shortName)
                .font(.caption2)
                .foregroundColor(.primary)
                .lineLimit(1)

            ProgressView(value: item.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: rowTint))

            HStack(spacing: 4) {
                statusBadge
                Spacer()
                Text(verbatim: "\(Int(item.progress * 100)) %")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    // Trim the internal timestamp and keep just the human-readable part.
    private var shortName: String {
        var name = item.fileName
        // Remove ".json.zlib" suffix
        name = name.replacingOccurrences(of: ".json.zlib", with: "")
        // Remove the leading "aw_" prefix
        if name.hasPrefix("aw_") { name = String(name.dropFirst(3)) }
        return name
    }

    private var rowTint: Color {
        if item.isCompleted { return .green }
        if item.isCancelled { return .red }
        if item.isPaused    { return .orange }
        return .blue
    }

    @ViewBuilder
    private var statusBadge: some View {
        if item.isCompleted {
            Label("完了", systemImage: "checkmark")
                .font(.caption2)
                .foregroundColor(.green)
        } else if item.isCancelled {
            Label("キャンセル", systemImage: "xmark")
                .font(.caption2)
                .foregroundColor(.red)
        } else if item.isPaused {
            Label("一時停止", systemImage: "pause")
                .font(.caption2)
                .foregroundColor(.orange)
        } else {
            EmptyView()
        }
    }
}

// MARK: - Compact badge (for embedding in other views)

/// A compact icon+progress indicator suitable for toolbars or smaller slots.
public struct AWDataTransferBadge: View {

    @ObservedObject public var manager: AWDataTransferManager

    public init(manager: AWDataTransferManager = .shared) {
        self.manager = manager
    }

    public var body: some View {
        HStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 3)
                    .frame(width: 22, height: 22)

                Circle()
                    .trim(from: 0, to: manager.overallProgress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 22, height: 22)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.4), value: manager.overallProgress)

                Image(systemName: iconName)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(tint)
            }

            if manager.state.isActive {
                Text(verbatim: "\(Int(manager.overallProgress * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var tint: Color {
        switch manager.state {
        case .completed: return .green
        case .failed:    return .red
        case .idle:      return .secondary
        default:         return .blue
        }
    }

    private var iconName: String {
        switch manager.state {
        case .completed: return "checkmark"
        case .failed:    return "exclamationmark"
        case .idle:      return "arrow.up.arrow.down"
        default:         return "arrow.up"
        }
    }
}

// MARK: - Preview

#Preview("Transfer Progress") {
    AWDataTransferProgressView()
}

#Preview("Transfer Badge") {
    AWDataTransferBadge()
        .padding()
}

#endif
