import SwiftUI

struct BackButton: View {
    @Binding var selected: AppTab

    var body: some View {
        Button {
            selected = .dashboard
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left").font(.system(size: 11, weight: .bold))
                Text("Back to Dashboard").font(.system(size: 12.5, weight: .semibold))
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Theme.panel2)
            .foregroundColor(Theme.muted)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
