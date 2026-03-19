
//
//  FormatHelpers.swift
//  Downshift
//
//  Shared formatting utilities.
//

import Foundation

func formatDuration(_ seconds: TimeInterval) -> String {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute, .second]
    formatter.unitsStyle = .positional
    formatter.zeroFormattingBehavior = .pad
    return formatter.string(from: seconds) ?? "00:00"
}

func formatShortDuration(_ seconds: TimeInterval) -> String {
    if seconds >= 3600 {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d:%02d", h, m, s)
    } else {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
