//
//  SwipeSelectApp.swift
//  SwipeSelect
//
//  Created by Jordan Hill on 27/03/2026.
//

import AppKit
import SwiftUI
import WidgetKit

// The AppDelegate bootstraps our engine early and hides the dock icon.
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run completely invisible in the background (faceless utility)
        NSApp.setActivationPolicy(.accessory)
        
        // If already trusted, boot the engine immediately
        if AXIsProcessTrusted() {
            GlideEngine.shared.start()
        } else {
            // Prompt and start polling — engine auto-starts when granted
            AccessibilityManager.shared.promptAndOpen()
        }
    }
}

@main
struct SwipeSelectApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // No main window — everything lives in the menu bar
        MenuBarExtra("SwipeSelect", systemImage: "cursorarrow.motionlines") {
            MenuBarPanel()
        }
        .menuBarExtraStyle(.window)
    }
}
