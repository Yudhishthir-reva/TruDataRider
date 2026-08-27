//
//  AuthHeader.swift
//  TrudataRider
//

import SwiftUI

private struct FloatingStar {
    let baseX: Double
    let baseY: Double
    let speed: Double
    let alpha: Double
    let size: CGFloat
    let diagonalRatio: Double
}

struct AuthHeader: View {
    var title: String = "Welcome to\nTruDataa Rider"
    var subtitle: String = "Pack and Deliver with Ease"

    @State private var startDate = Date()
    @State private var contentOpacity: Double = 0.0

    private static let stars: [FloatingStar] = (0..<50).map { i in
        let seed = Double(i)
        // Deterministic pseudo-random distribution
        let baseX = (seed * 0.173 + 0.05).truncatingRemainder(dividingBy: 1.0)
        let baseY = (seed * 0.281 + 0.08).truncatingRemainder(dividingBy: 1.0)
        // Individual speeds in 0.0001 - 0.0003 range
        let speed = 0.0001 + ((seed * 7.91).truncatingRemainder(dividingBy: 1.0)) * 0.0002
        // Alpha opacities in 0.1 - 0.7 range
        let alpha = 0.1 + ((seed * 13.37).truncatingRemainder(dividingBy: 1.0)) * 0.6
        let size: CGFloat = 1.5 + CGFloat((seed * 3.14).truncatingRemainder(dividingBy: 1.0)) * 1.5
        let diagonalRatio = 0.35 + ((seed * 5.21).truncatingRemainder(dividingBy: 1.0)) * 0.35

        return FloatingStar(
            baseX: baseX,
            baseY: baseY,
            speed: speed,
            alpha: alpha,
            size: size,
            diagonalRatio: diagonalRatio
        )
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            starfield

            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white)
                    .lineSpacing(8)
                Text(subtitle)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .lineSpacing(2)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1.5, contentMode: .fit)
        .clipped()
        .opacity(contentOpacity)
        .onAppear {
            startDate = Date()
            withAnimation(.easeInOut(duration: 1.0)) {
                contentOpacity = 1.0
            }
        }
    }

    private var starfield: some View {
        TimelineView(.animation) { timeline in
            let timeMs = timeline.date.timeIntervalSince(startDate) * 1000.0
            Canvas { context, size in
                // Space Theme Background #0F2C42
                let bgRect = CGRect(origin: .zero, size: size)
                context.fill(Path(bgRect), with: .color(Color(hex: "0F2C42")))

                // 8x8 Grid lines #1A4668
                let gridColor = Color(hex: "1A4668")
                let lines = 8
                let stepX = size.width / CGFloat(lines)
                let stepY = size.height / CGFloat(lines)
                for i in 1..<lines {
                    var vertical = Path()
                    vertical.move(to: CGPoint(x: CGFloat(i) * stepX, y: 0))
                    vertical.addLine(to: CGPoint(x: CGFloat(i) * stepX, y: size.height))
                    context.stroke(vertical, with: .color(gridColor), lineWidth: 1)

                    var horizontal = Path()
                    horizontal.move(to: CGPoint(x: 0, y: CGFloat(i) * stepY))
                    horizontal.addLine(to: CGPoint(x: size.width, y: CGFloat(i) * stepY))
                    context.stroke(horizontal, with: .color(gridColor), lineWidth: 1)
                }

                // Diagonal Halo Glow: Top-right quadrant (75% width, 25% height)
                let haloCenter = CGPoint(x: size.width * 0.75, y: size.height * 0.25)
                let haloRadius = max(size.width, size.height) * 0.7
                let haloRect = CGRect(
                    x: haloCenter.x - haloRadius,
                    y: haloCenter.y - haloRadius,
                    width: haloRadius * 2,
                    height: haloRadius * 2
                )
                context.fill(
                    Path(ellipseIn: haloRect),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color.white.opacity(0.20),
                            Color(hex: "1A4668").opacity(0.15),
                            Color.clear
                        ]),
                        center: haloCenter,
                        startRadius: 0,
                        endRadius: haloRadius
                    )
                )

                // 50 Floating Space Stars (Continuous 60/120 FPS Animation)
                for star in Self.stars {
                    var x = star.baseX + timeMs * (star.speed * star.diagonalRatio)
                    var y = star.baseY + timeMs * star.speed

                    // Boundary wrap-around
                    x = x.truncatingRemainder(dividingBy: 1.0)
                    if x < 0 { x += 1.0 }
                    y = y.truncatingRemainder(dividingBy: 1.0)
                    if y < 0 { y += 1.0 }

                    let starRect = CGRect(
                        x: x * size.width,
                        y: y * size.height,
                        width: star.size,
                        height: star.size
                    )
                    context.fill(
                        Path(ellipseIn: starRect),
                        with: .color(.white.opacity(star.alpha))
                    )
                }
            }
        }
    }
}

#Preview {
    AuthHeader()
}

