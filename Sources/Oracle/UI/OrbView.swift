import SwiftUI

struct OrbView: View {
    let state: AssistantState
    
    @State private var pulsePhase = 0.0
    @State private var rotation = 0.0
    
    private var orbColors: [Color] {
        switch state {
        case .idle:
            return [
                .purple.opacity(0.8), .indigo.opacity(0.6), .blue.opacity(0.5),
                .indigo.opacity(0.7), .purple.opacity(0.9), .blue.opacity(0.4),
                .blue.opacity(0.6), .purple.opacity(0.7), .indigo.opacity(0.8)
            ]
        case .listening:
            return [
                .green.opacity(0.8), .teal.opacity(0.6), .cyan.opacity(0.5),
                .teal.opacity(0.7), .green.opacity(0.9), .cyan.opacity(0.4),
                .cyan.opacity(0.6), .green.opacity(0.7), .teal.opacity(0.8)
            ]
        case .thinking:
            return [
                .orange.opacity(0.8), .pink.opacity(0.6), .red.opacity(0.5),
                .pink.opacity(0.7), .orange.opacity(0.9), .red.opacity(0.4),
                .red.opacity(0.6), .orange.opacity(0.7), .pink.opacity(0.8)
            ]
        case .speaking:
            return [
                .purple.opacity(0.9), .blue.opacity(0.7), .pink.opacity(0.6),
                .blue.opacity(0.8), .purple.opacity(1.0), .pink.opacity(0.5),
                .pink.opacity(0.7), .purple.opacity(0.8), .blue.opacity(0.9)
            ]
        case .transcribing, .toolExecuting:
            return [
                .gray.opacity(0.6), .gray.opacity(0.5), .gray.opacity(0.4),
                .gray.opacity(0.5), .gray.opacity(0.7), .gray.opacity(0.4),
                .gray.opacity(0.5), .gray.opacity(0.6), .gray.opacity(0.5)
            ]
        }
    }
    
    private var baseScale: CGFloat {
        switch state {
        case .idle: 1.0
        case .listening: 1.05
        case .thinking: 1.1
        case .speaking: 1.08
        case .transcribing: 1.0
        case .toolExecuting: 1.0
        }
    }
    
    private var volumeScale: CGFloat {
        if case .listening(let volume) = state {
            return CGFloat(volume) * 0.3
        }
        return 0
    }
    
    var body: some View {
        ZStack {
            // Outer glow rings
            ForEach(0..<3) { i in
                    Circle()
                        .fill(
                            MeshGradient(
                                width: 3, height: 3,
                                points: [
                                    .init(x: 0, y: 0), .init(x: 0.5, y: 0), .init(x: 1, y: 0),
                                    .init(x: 0, y: 0.5), .init(x: 0.5, y: 0.5), .init(x: 1, y: 0.5),
                                    .init(x: 0, y: 1), .init(x: 0.5, y: 1), .init(x: 1, y: 1)
                                ],
                                colors: orbColors.map { $0.opacity(0.3 - Double(i) * 0.08) }
                            )
                        )
                        .frame(width: 140 + CGFloat(i) * 40, height: 140 + CGFloat(i) * 40)
                        .scaleEffect(baseScale + volumeScale + pulseAnimation(for: i))
                        .blur(radius: CGFloat(20 + i * 10))
                }
                
                // Main orb
                Circle()
                    .fill(
                        MeshGradient(
                            width: 3, height: 3,
                            points: [
                                .init(x: 0, y: 0), .init(x: 0.5, y: 0), .init(x: 1, y: 0),
                                .init(x: 0, y: 0.5), .init(x: 0.5, y: 0.5), .init(x: 1, y: 0.5),
                                .init(x: 0, y: 1), .init(x: 0.5, y: 1), .init(x: 1, y: 1)
                            ],
                            colors: orbColors
                        )
                    )
                    .frame(width: 100, height: 100)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.2), lineWidth: 0.8)
                    )
                    .scaleEffect(baseScale + volumeScale)
                    .shadow(color: orbColors[4].opacity(0.5), radius: 30, x: 0, y: 0)
                
                // Inner highlight
                Circle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 50, height: 50)
                    .blur(radius: 12)
                    .offset(y: -20)
                    .scaleEffect(baseScale + volumeScale * 0.5)
                
                // Thinking rotation ring
                if case .thinking = state {
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            AngularGradient(
                                colors: [.purple, .blue, .pink, .purple],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 130, height: 130)
                        .rotationEffect(.degrees(rotation))
                }
                
                // Listening waveform ring
                if case .listening = state {
                    Circle()
                        .stroke(
                            Color.green.opacity(0.4 + Double(volumeScale)),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 5])
                        )
                        .frame(width: 120 + CGFloat(volumeScale * 60), height: 120 + CGFloat(volumeScale * 60))
                }
            }
        }
        .drawingGroup()
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulsePhase = 1.0
            }
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
    
    private func pulseAnimation(for index: Int) -> CGFloat {
        let offset = Double(index) * 0.5
        let value = sin((pulsePhase + offset) * .pi * 2)
        return CGFloat(value * 0.08)
    }
}
