//
//  TabButton.swift
//  boringNotch
//
//  Created by Hugo Persson on 2024-08-24.
//

import SwiftUI

enum TabIcon {
    case system(String)
    case codex
}

struct TabButton: View {
    let label: String
    let icon: TabIcon
    let selected: Bool
    let onClick: () -> Void
    
    var body: some View {
        Button(action: onClick) {
            iconView
                .padding(.horizontal, 15)
                .contentShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .system(let name):
            Image(systemName: name)
        case .codex:
            CodexGlyph(size: 15)
        }
    }
}

#Preview {
    TabButton(label: "Home", icon: .system("tray.fill"), selected: true) {
        print("Tapped")
    }
}
