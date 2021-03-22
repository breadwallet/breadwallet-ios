//
//  ChartView.swift
//  ChartDemo
//
//  Created by stringcode on 11/02/2021.
//  Copyright © 2021 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import SwiftUI

struct ChartView: View {
    
    @State var viewModel: ChartViewModel = ChartViewModel.mock()

    var body: some View {
        GeometryReader { geometry in
            
            let points = self.points(viewModel.candles, size: geometry.size)
            
            ZStack {
                path(with: points, close: false)
                    .stroke(viewModel.chartColor, lineWidth: 1)
                path(with: points + [geometry.size.maxXmaxY, geometry.size.minXmaxY], close: true)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: colors(for: viewModel)),
                            startPoint: .top, endPoint: .bottom)
                    )
            }
        }
    }
}

// MARK: - Helper methods

private extension ChartView {
    
    func points(_ candles: [ChartViewModel.Candle], size: CGSize) -> [CGPoint] {
        let candleWidth = size.width / candles.count.cgfloat
        return candles.enumerated().map {
            .init(
                x: candleWidth * $0.0.cgfloat,
                y: (1 - $0.1.close.cgfloat) * size.height
            )
        }
    }
    
    func path(with points: [CGPoint], close: Bool = false) -> Path {
        guard !points.isEmpty else {
            return Path { path in
                path.move(to: .zero)
            }
        }
        
        return Path { path in
            path.move(to: points[0])
            
            for idx in (1..<points.count) {
                path.addLine(to: points[idx])
            }
            
            if close {
                path.closeSubpath()
            }
        }
    }
    
    func colors(for viewModel: ChartViewModel) -> [Color] {
        return [
            viewModel.chartColor.opacity(0.5),
            viewModel.chartColor.opacity(0)
        ]
    }
}

struct ChartView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ChartView()
                .preferredColorScheme(.dark)
                .previewLayout(PreviewLayout.fixed(width: 250, height: 250))
                .padding()
                .previewDisplayName("Default preview 1")
                
        }
    }
}
