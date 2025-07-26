//
//  OnboardingManager.swift
//  menuCal
//
//  Created by 차원준 on 6/23/25.
//

import AppKit
import SwiftUI

class OnboardingManager {
    // MARK: - 온보딩 상태 확인

    static func shouldShowOnboarding() -> Bool {
        return !UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
    }
    
    // MARK: - 온보딩 표시

    static func showOnboarding() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("System Setup Required", comment: "Setup alert title")
        alert.informativeText = NSLocalizedString("Please follow these steps to hide the system date:\n\n1. Open System Settings\n2. Go to Control Center\n3. Select Clock Options\n4. Set 'Show Date' to 'Never'\n\nThis will prevent duplicate dates in your menu bar.", comment: "Setup alert message")
        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("Open System Settings", comment: "Open settings button"))
        alert.addButton(withTitle: NSLocalizedString("OK", comment: "OK button"))
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // "Open System Settings" 버튼을 클릭한 경우
            openSystemSettings()
        }
        
        // 온보딩 완료 표시
        markOnboardingComplete()
    }
    
    // MARK: - 시스템 설정 열기

    private static func openSystemSettings() {
        if #available(macOS 13.0, *) {
            // macOS 13 이상에서는 새로운 System Settings 앱
            let url = URL(string: "x-apple.systempreferences:com.apple.ControlCenter-Settings.extension")!
            NSWorkspace.shared.open(url)
        } else {
            // macOS 12 이하에서는 기존 System Preferences
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.dock")!
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - 온보딩 완료 처리

    static func markOnboardingComplete() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
    }
    
    // MARK: - 온보딩 상태 리셋 (개발/테스트용)

    static func resetOnboarding() {
        UserDefaults.standard.removeObject(forKey: "hasSeenOnboarding")
    }
}
