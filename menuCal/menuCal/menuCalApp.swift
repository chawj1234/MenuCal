//
//  menuCalApp.swift
//  menuCal
//
//  Created by 차원준 on 6/23/25.
//

import SwiftUI
import AppKit
import ServiceManagement

@main
struct menuCalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 독 아이콘 숨기기
        NSApp.setActivationPolicy(.accessory)
        
        // 로그인 시 자동 시작 설정
        enableLoginItem()
        
        // 상태바 아이템 생성
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            updateDateDisplay()
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        // 1분마다 날짜 업데이트
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            self.updateDateDisplay()
        }
        
        // 팝오버 설정
        popover = NSPopover()
        popover?.contentViewController = NSHostingController(rootView: ContentView())
        popover?.behavior = .transient
    }
    
    @objc func togglePopover() {
        guard let button = statusItem?.button else { return }
        
        if let popover = popover {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
    
    private func updateDateDisplay() {
        DispatchQueue.main.async {
            if let button = self.statusItem?.button {
                let formatter = DateFormatter()
                formatter.locale = Locale.current
                
                // 날짜만 표시 (예: "24")
                formatter.dateFormat = "d"
                
                button.title = formatter.string(from: Date())
            }
        }
    }
    
    // 로그인 시 자동 시작 활성화
    private func enableLoginItem() {
        if #available(macOS 13.0, *) {
            // macOS 13 이상에서는 새로운 API 사용
            do {
                try SMAppService.mainApp.register()
                print("✅ 로그인 아이템이 성공적으로 등록되었습니다.")
            } catch {
                print("❌ 로그인 아이템 등록 실패: \(error.localizedDescription)")
            }
        } else {
            // macOS 12 이하에서는 기존 API 사용
            let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.yourcompany.menuCal"
            
            if SMLoginItemSetEnabled(bundleIdentifier as CFString, true) {
                print("✅ 로그인 아이템이 성공적으로 등록되었습니다.")
            } else {
                print("❌ 로그인 아이템 등록에 실패했습니다.")
            }
        }
    }
    
    // 로그인 시 자동 시작 비활성화
    private func disableLoginItem() {
        if #available(macOS 13.0, *) {
            // macOS 13 이상에서는 새로운 API 사용
            do {
                try SMAppService.mainApp.unregister()
                print("✅ 로그인 아이템이 성공적으로 해제되었습니다.")
            } catch {
                print("❌ 로그인 아이템 해제 실패: \(error.localizedDescription)")
            }
        } else {
            // macOS 12 이하에서는 기존 API 사용
            let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.yourcompany.menuCal"
            
            if SMLoginItemSetEnabled(bundleIdentifier as CFString, false) {
                print("✅ 로그인 아이템이 성공적으로 해제되었습니다.")
            } else {
                print("❌ 로그인 아이템 해제에 실패했습니다.")
            }
        }
    }
} 