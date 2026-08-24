//
//  ProfileView.swift
//  TrudataRider
//
//

import SwiftUI

struct ProfileView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ProfileViewModel()

    var onBack: (() -> Void)?
    var onHome: (() -> Void)?

    private let screenBackground = Color(hex: "F4F6F9")
    private let iconBlue = Color(hex: "2563EB")
    private let labelGray = Color(hex: "9CA3AF")
    private let textDark = Color(hex: "111827")
    private let sectionTitleColor = Color(hex: "1F2937")

    var body: some View {
        ZStack {
            screenBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                appBar
                content
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            viewModel.onAppear()
        }
    }

    // MARK: - App Bar

    private var appBar: some View {
        HStack(spacing: 14) {
            Button {
                if let onBack {
                    onBack()
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
            }

            Text(viewModel.headerTitle)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            Button {
                viewModel.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
            }

            Button {
                if let onHome {
                    onHome()
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "house.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 14)
        .background(AppTheme.darkMidnightBlue.ignoresSafeArea(edges: .top))
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.profile == nil {
            ProgressView()
                .tint(AppTheme.darkMidnightBlue)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.profile == nil {
            VStack(spacing: 14) {
                Text(error)
                    .font(.system(size: 15))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(labelGray)
                Button("Retry") {
                    viewModel.refresh()
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(iconBlue)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let profile = viewModel.profile {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    heroProfileCard(profile)
                    employmentDetailsCard(profile)
                    contactInformationCard(profile)
                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .refreshable {
                viewModel.refresh()
            }
        }
    }

    // MARK: - Hero Profile Card

    private func heroProfileCard(_ profile: UserProfileDetail) -> some View {
        VStack(spacing: 14) {
            ProfileAvatarView(profilePic: profile.profilePic, size: 94)

            VStack(spacing: 4) {
                Text(profile.name.isEmptyString ? "User" : profile.name)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(profile.subtitle)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "3B59F5"), Color(hex: "7C3AED")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .shadow(color: Color(hex: "3B59F5").opacity(0.2), radius: 10, x: 0, y: 6)
    }

    // MARK: - Employment Details Card

    private func employmentDetailsCard(_ profile: UserProfileDetail) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Employment Details")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(sectionTitleColor)

            VStack(alignment: .leading, spacing: 16) {
                ProfileInfoRow(
                    iconName: "briefcase.fill",
                    label: "Role",
                    value: profile.role.isEmptyString ? "Rider" : profile.role,
                    iconColor: iconBlue
                )

                ProfileInfoRow(
                    iconName: "calendar",
                    label: "Joining Date",
                    value: profile.joiningDate.isEmptyString ? "-" : profile.joiningDate,
                    iconColor: iconBlue
                )

                ProfileInfoRow(
                    iconName: "checkmark.circle.fill",
                    label: "Status",
                    value: profile.status.isEmptyString ? "Active" : profile.status,
                    iconColor: iconBlue
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        }
    }

    // MARK: - Contact Information Card

    private func contactInformationCard(_ profile: UserProfileDetail) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Contact Information")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(sectionTitleColor)

            VStack(alignment: .leading, spacing: 16) {
                if let callURL = profile.callURL {
                    Link(destination: callURL) {
                        ProfileInfoRow(
                            iconName: "phone.fill",
                            label: "Mobile",
                            value: profile.mobile.isEmptyString ? "-" : profile.mobile,
                            iconColor: iconBlue
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    ProfileInfoRow(
                        iconName: "phone.fill",
                        label: "Mobile",
                        value: profile.mobile.isEmptyString ? "-" : profile.mobile,
                        iconColor: iconBlue
                    )
                }

                if let mailURL = profile.mailURL {
                    Link(destination: mailURL) {
                        ProfileInfoRow(
                            iconName: "envelope.fill",
                            label: "Email",
                            value: profile.displayEmail,
                            iconColor: iconBlue
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    ProfileInfoRow(
                        iconName: "envelope.fill",
                        label: "Email",
                        value: profile.displayEmail,
                        iconColor: iconBlue
                    )
                }

                ProfileInfoRow(
                    iconName: "building.2.fill",
                    label: "Location",
                    value: profile.location.isEmptyString ? "-" : profile.location,
                    iconColor: iconBlue
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        }
    }
}

// MARK: - Profile Info Row Component

struct ProfileInfoRow: View {
    let iconName: String
    let label: String
    let value: String
    var iconColor: Color = Color(hex: "2563EB")

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 24, height: 24, alignment: .center)

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color(hex: "9CA3AF"))

                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "111827"))
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Profile Avatar Component

struct ProfileAvatarView: View {
    let profilePic: String
    var size: CGFloat = 94

    var body: some View {
        if !profilePic.isEmptyString {
            RemoteImage(url: profilePic)
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.black, lineWidth: 2.5))
        } else {
            defaultIllustratedAvatar
        }
    }

    private var defaultIllustratedAvatar: some View {
        ZStack {
            // Yellow background
            Circle()
                .fill(Color(hex: "F59E0B"))
                .frame(width: size, height: size)

            // Character bust and head
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                ZStack {
                    // Gray shoulders / torso
                    Path { path in
                        path.move(to: CGPoint(x: w * 0.14, y: h * 0.96))
                        path.addCurve(
                            to: CGPoint(x: w * 0.86, y: h * 0.96),
                            control1: CGPoint(x: w * 0.20, y: h * 0.58),
                            control2: CGPoint(x: w * 0.80, y: h * 0.58)
                        )
                        path.addLine(to: CGPoint(x: w * 0.86, y: h * 1.05))
                        path.addLine(to: CGPoint(x: w * 0.14, y: h * 1.05))
                        path.closeSubpath()
                    }
                    .fill(Color(hex: "9CA3AF"))

                    Path { path in
                        path.move(to: CGPoint(x: w * 0.14, y: h * 0.96))
                        path.addCurve(
                            to: CGPoint(x: w * 0.86, y: h * 0.96),
                            control1: CGPoint(x: w * 0.20, y: h * 0.58),
                            control2: CGPoint(x: w * 0.80, y: h * 0.58)
                        )
                    }
                    .stroke(Color.black, lineWidth: 2.5)

                    // Head
                    Circle()
                        .fill(Color(hex: "FED7AA"))
                        .frame(width: w * 0.42, height: h * 0.42)
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: 2.5)
                        )
                        .position(x: w * 0.5, y: h * 0.42)
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())

            // Outer dark border
            Circle()
                .stroke(Color.black, lineWidth: 2.5)
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    ProfileView()
}
