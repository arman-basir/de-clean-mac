import SwiftUI

/// The De Clean Mac logo, drawn entirely in code: a sweeping "wipe" arc with
/// a sparkle at its open end. No image files are loaded, so there's no
/// dependency on SwiftPM resource bundles (which is what caused a crash on
/// launch when the app was packaged outside of Xcode).
struct LogoMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "1D262D"), Color(hex: "0A0E11")],
                        center: .topLeading, startRadius: 2, endRadius: 40
                    )
                )

            Circle()
                .trim(from: 0.08, to: 0.78)
                .stroke(
                    AngularGradient(colors: [Theme.mint, Theme.violet], center: .center),
                    style: StrokeStyle(lineWidth: 3.4, lineCap: .round)
                )
                .rotationEffect(.degrees(90))
                .padding(6)

            Image(systemName: "sparkle")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white)
                .offset(x: 6, y: -6)
        }
    }
}
