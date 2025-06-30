//
//  menuCalApp.swift
//  menuCal
//
//  Created by 차원준 on 6/23/25.
//

import SwiftUI
import AppKit
// import ServiceManagement  // 자동 실행 기능을 위해 필요한 경우 주석 해제

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
    var statusBarMenu: NSMenu?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 독 아이콘 숨기기
        NSApp.setActivationPolicy(.accessory)
        
        // 로그인 시 자동 시작 설정 (필요한 경우 주석 해제)
        // enableLoginItem()
        
        // 상태바 아이템 생성
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            updateDateDisplay()
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // 상태바 메뉴 설정
        setupStatusBarMenu()
        
        // 1분마다 날짜 업데이트
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            self.updateDateDisplay()
        }
        
        // 팝오버 설정
        popover = NSPopover()
        popover?.contentViewController = NSHostingController(rootView: ContentView())
        popover?.behavior = .transient
        
        // 키보드 단축키 지원 (Cmd+Q로 종료)
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "q" {
                self.quitApp()
                return nil
            }
            return event
        }
    }
    
    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            // 우클릭 - 메뉴 표시
            statusItem?.menu = statusBarMenu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
        } else {
            // 좌클릭 - 팝오버 토글
            togglePopover()
        }
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
    
    private func setupStatusBarMenu() {
        statusBarMenu = NSMenu()
        
        // About 메뉴 아이템
        let aboutMenuItem = NSMenuItem(title: NSLocalizedString("About MenuCal", comment: "About menu item"), 
                                       action: #selector(showAbout), 
                                       keyEquivalent: "")
        aboutMenuItem.target = self
        statusBarMenu?.addItem(aboutMenuItem)
        
        // 구분선
        statusBarMenu?.addItem(NSMenuItem.separator())
        
        // Quit 메뉴 아이템
        let quitMenuItem = NSMenuItem(title: NSLocalizedString("Quit MenuCal", comment: "Quit menu item"), 
                                      action: #selector(quitApp), 
                                      keyEquivalent: "q")
        quitMenuItem.target = self
        statusBarMenu?.addItem(quitMenuItem)
    }
    
    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("About MenuCal", comment: "About dialog title")
        alert.informativeText = NSLocalizedString("MenuCal is a simple calendar and weather app for your menu bar.\n\nVersion 1.0\n\nWeather data provided by Apple Weather", comment: "About dialog content")
        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("OK", comment: "OK button"))
        alert.runModal()
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    private func updateDateDisplay() {
        DispatchQueue.main.async {
            if let button = self.statusItem?.button {
                let calendar = Calendar.current
                let day = calendar.component(.day, from: Date())
                
                // 영어 서수 표현으로 변환 (1st, 2nd, 3rd, 4th, ...)
                let numberFormatter = NumberFormatter()
                numberFormatter.numberStyle = .ordinal
                numberFormatter.locale = Locale(identifier: "en_US")
                
                let ordinalDay = numberFormatter.string(from: NSNumber(value: day)) ?? "\(day)"
                
                button.title = ordinalDay
            }
        }
    }
    
    // 로그인 시 자동 시작 활성화 (필요한 경우 주석 해제)
    /*
    private func enableLoginItem() {
        if #available(macOS 13.0, *) {
            // macOS 13 이상에서는 새로운 API 사용
            do {
                try SMAppService.mainApp.register()
            } catch {
                print("로그인 아이템 등록 실패: \(error.localizedDescription)")
            }
        } else {
            // macOS 12 이하에서는 기존 API 사용
            let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.yourcompany.menuCal"
            
            _ = SMLoginItemSetEnabled(bundleIdentifier as CFString, true)
        }
    }
    */
} 