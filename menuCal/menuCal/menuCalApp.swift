//
//  menuCalApp.swift
//  menuCal
//
//  Created by 차원준 on 6/23/25.
//

import SwiftUI
import AppKit

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
} 