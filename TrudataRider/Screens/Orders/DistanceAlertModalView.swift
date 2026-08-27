//
//  DistanceAlertModalView.swift
//  TrudataRider
//

import SwiftUI

struct DistanceAlertModalView: View {

    let shopName: String
    let distanceText: String
    let onCancel: () -> Void
    let onDeliverAnyway: () -> Void

    private let alertRed = Color(red: 0.85, green: 0.20, blue: 0.20)
    private let appBlue = Color(red: 0.00, green: 0.20, blue: 0.31)

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(spacing: 18) {
                Circle()
                    .fill(alertRed.opacity(0.10))
                    .frame(width: 68, height: 68)
                    .overlay {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(alertRed)
                    }

                Text("Distance Alert")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.primary)

                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "mappin")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(appBlue)
                        .padding(.top, 2)

                    VStack(spacing: 2) {
                        Text("You are \(distanceText) away from")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color.secondary)

                        Text(shopName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.primary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 8)

                Text("आप डिलीवरी की जगह से 100 मीटर से ज़्यादा दूर हैं। क्या आप पक्का ये ऑर्डर डिलीवर करना चाहते हैं?")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 6)

                HStack(spacing: 12) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.gray.opacity(0.35), lineWidth: 1)
                            }
                    }

                    Button(action: onDeliverAnyway) {
                        Text("Deliver\nAnyway")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(alertRed)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(.top, 6)
            }
            .padding(22)
            .frame(maxWidth: 330)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.20), radius: 20, y: 8)
            .padding(.horizontal, 24)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: true)
    }
}

#Preview {
    DistanceAlertModalView(
        shopName: "Laxmi Kirana Store Champa Nagar",
        distanceText: "766m",
        onCancel: {},
        onDeliverAnyway: {}
    )
}
