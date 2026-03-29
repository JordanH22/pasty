//
//  ContentView.swift
//  SwipeSelect
//
//  Created by Jordan Hill on 27/03/2026.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var axManager = AccessibilityManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: axManager.isTrusted ? "hand.draw.fill" : "lock.shield.fill")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(axManager.isTrusted ? .green : .red)
            
            Text("Glide Engine")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
            
            if axManager.isTrusted {
                Text("Interceptor Active")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("Your trackpad is now natively hooked into macOS globally. Swipe 2 fingers horizontally over any text box to move your cursor.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 5)
            } else {
                Text("Accessibility Required")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("SwipeSelect needs Accessibility access to intercept trackpad scrolls and move your text cursor.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .padding(.top, 5)
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("Click the button below to open Privacy settings", systemImage: "1.circle.fill")
                        .font(.caption)
                    Label("Click the + button and add SwipeSelect", systemImage: "2.circle.fill")
                        .font(.caption)
                    Label("Toggle SwipeSelect ON and restart the app", systemImage: "3.circle.fill")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 30)
                .padding(.top, 5)
                
                Button("Open Accessibility Settings") {
                    AccessibilityManager.shared.promptAndOpen()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 10)
                
                Text("⏳ Recent macOS versions may take up to 2 minutes to load Accessibility settings. Please be patient and allow it time to load.")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .padding(.top, 4)
            }
        }
        .padding(40)
        .frame(width: 480, height: 480)
        // Keep window on top for setup
        .onAppear {
            if let window = NSApplication.shared.windows.first {
                window.level = .floating
            }
        }
    }
}

#Preview {
    ContentView()
}
