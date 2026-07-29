//
//  CodexGlyph.swift
//  boringNotch
//

import SwiftUI

struct CodexGlyph: View {
    var size: CGFloat = 16

    var body: some View {
        ZStack {
            Image(systemName: "cloud.fill")
                .font(.system(size: size, weight: .semibold))

            Text(">_")
                .font(.system(size: size * 0.28, weight: .black, design: .monospaced))
                .foregroundStyle(.black)
                .offset(y: size * 0.05)
        }
        .frame(width: size * 1.25, height: size)
        .accessibilityHidden(true)
    }
}
