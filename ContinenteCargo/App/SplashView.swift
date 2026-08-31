//
//  SplashView.swift
//  ContinenteCargo
//
//  Full-screen launch screen shown on cold start while the session
//  initialises. Uses the real company logo on a clean white background.
//

import SwiftUI

struct SplashView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image("LogoLockupStacked")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 240)
                    .scaleEffect(appeared ? 1 : 0.88)
                    .opacity(appeared ? 1 : 0)

                Spacer()

                ProgressView()
                    .tint(CCColor.navy.opacity(0.4))
                    .opacity(appeared ? 1 : 0)
                    .padding(.bottom, 52)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }
        }
    }
}

#Preview {
    SplashView()
}
