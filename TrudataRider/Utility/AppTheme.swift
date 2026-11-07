//
//  AppTheme.swift
//  TrudataRider
//

import SwiftUI

/// Every colour that changes when the brand changes.
///
/// One property per *original* colour rather than per hue — this mirrors the Android app's
/// `BrandColors` exactly, so the two platforms stay in step. Several of the dark tones land on the
/// same green under the green identity; under blue they were genuinely different colours in
/// different places, and collapsing them would quietly restyle the blue theme on the way past.
///
/// Status colours (danger red, warning amber, success green) are deliberately absent: a danger red
/// has to stay red whatever the brand is.
struct BrandColors {
    /// The working brand colour: primary buttons, active icons, selected states.
    let primary: Color
    /// The heavier companion to `primary`, for pressed and raised states.
    let primaryDark: Color
    /// The second brand tone, used where two brand colours must be told apart.
    let accent: Color
    /// The darkest brand tone — gradient tails and headline chrome.
    let deep: Color
    /// A tone darker still than `deep`, used for pressed states on the CTA gradient.
    let deepShadow: Color
    /// Mid-depth brand tone: field labels and secondary headings.
    let mid: Color
    /// The brightest brand tone: focused field borders and links.
    let bright: Color
    /// Soft brand-tinted fill behind chips, icon discs and selected rows.
    let container: Color
    /// The page a screen sits on. White under the green identity, deliberately: a tinted canvas
    /// made every screen read as a green wash rather than a white app with green furniture.
    let canvas: Color
    /// Neutral page background.
    let surface: Color
    /// Hairlines, dividers, and the fill of muted empty states.
    let surfaceVariant: Color
    /// The near-black used for borders that need to read as structural.
    let border: Color
    /// The head of the shared app bar's gradient. Its tail is `deep`.
    let barTop: Color
    /// The star-field auth header's backdrop, and the grid drawn a shade lighter over it.
    let headerBg: Color
    let headerGrid: Color
    /// The dashboard hero's three-stop gradient, plus the light that plays over it.
    let heroTop: Color
    let heroMid: Color
    let heroBottom: Color
    let heroGlow: Color
    /// The two stops of the full-page background gradient behind the dashboard and long forms.
    let washTop: Color
    let washBottom: Color
    /// Background behind an unranked leaderboard position.
    let rankNeutral: Color
    /// Tile behind a thumbnail or placeholder image.
    let imageTile: Color
    /// The wordmark's accent, used by `TruDataaLogo`.
    let logo: Color
}

extension BrandColors {

    /// The green identity, sampled from the SpiceMonk design system — matches Android's `GreenBrand`.
    static let green = BrandColors(
        primary: Color(hex: "167444"),
        primaryDark: Color(hex: "0E4A28"),
        accent: Color(hex: "0D9488"),
        deep: Color(hex: "0E4A28"),
        deepShadow: Color(hex: "0A3419"),
        mid: Color(hex: "167444"),
        bright: Color(hex: "1E8A52"),
        container: Color(hex: "E8F5EE"),
        canvas: Color(hex: "FFFFFF"),
        surface: Color(hex: "FAFAFA"),
        surfaceVariant: Color(hex: "E7EEE9"),
        border: Color(hex: "14311F"),
        barTop: Color(hex: "1D8750"),
        headerBg: Color(hex: "0F2E1E"),
        headerGrid: Color(hex: "1A5636"),
        heroTop: Color(hex: "0E4A28"),
        heroMid: Color(hex: "167444"),
        heroBottom: Color(hex: "1D8750"),
        heroGlow: Color(hex: "34D399"),
        // A soft green-grey, not white: the dashboard cards are white, and on a white wash their
        // edges vanished. The blue identity's wash was tinted for the same reason.
        washTop: Color(hex: "E3EDE7"),
        washBottom: Color(hex: "EDF1EE"),
        rankNeutral: Color(hex: "B7E4C7"),
        imageTile: Color(hex: "EDF3EF"),
        logo: Color(hex: "34D399")
    )

    /// The original blue identity, value for value as it was before the flag existed.
    static let blue = BrandColors(
        primary: Color(hex: "225EC2"),
        primaryDark: Color(hex: "3730A3"),
        accent: Color(hex: "0891B2"),
        deep: Color(hex: "002B45"),
        deepShadow: Color(hex: "001C2E"),
        mid: Color(hex: "005273"),
        bright: Color(hex: "0077B6"),
        container: Color(hex: "F0F8FF"),
        canvas: Color(hex: "F0F8FF"),
        surface: Color(hex: "FAFAFA"),
        surfaceVariant: Color(hex: "EBEBF3"),
        border: Color(hex: "1A2436"),
        barTop: Color(hex: "14446A"),
        headerBg: Color(hex: "0F2C42"),
        headerGrid: Color(hex: "1A4668"),
        heroTop: Color(hex: "00203A"),
        heroMid: Color(hex: "0B4A72"),
        heroBottom: Color(hex: "0E7490"),
        heroGlow: Color(hex: "22D3EE"),
        washTop: Color(hex: "DEE6F8"),
        washBottom: Color(hex: "E7EBEF"),
        rankNeutral: Color(hex: "BFDBFE"),
        imageTile: Color(hex: "EEF3F8"),
        logo: Color(hex: "29ABE2")
    )
}

enum AppTheme {

    /// Switches the whole app between the two brand identities.
    ///
    /// `true` gives the green identity; `false` restores the original blue one *exactly* — every
    /// value in `BrandColors.blue` is the literal that used to be hard-coded at that spot, so
    /// flipping back is a true revert rather than an approximation. Nothing else needs touching:
    /// every brand-dependent colour in the app resolves through `AppTheme.brand`.
    static let useGreenTheme = true

    static let brand: BrandColors = useGreenTheme ? .green : .blue

    // MARK: - Brand tokens (names kept from the blue era so call sites did not have to move)

    static let darkMidnightBlue = brand.deep
    static let cerulean = brand.mid
    static let aliceBlue = brand.container
    static let blue = brand.bright
    static let logoCyan = brand.logo

    // MARK: - Neutrals

    static let silver = Color(hex: "9CA3AF")
    static let gainsboro = Color(hex: "D1D5DB")
    static let whiteSmoke = Color(hex: "F5F5F5")
    static let slateGray = Color(hex: "6B7280")

    // MARK: - Chrome

    /// Kept at the original dark blue on purpose — Android's `colors.xml` splash is still `#002B45`,
    /// and the launch screen has to match the static asset on both platforms.
    static let splashBackground = Color(hex: "002B45")
    static let authHeader = brand.headerBg
    static let authGrid = brand.headerGrid

    // MARK: - Status

    static let errorRed = Color(hex: "DC2626")
    static let errorRedBg = Color(hex: "FFF1F2")
    static let errorRedText = Color(hex: "7F1D1D")

    // MARK: - Page backgrounds

    static let brandBackgroundTop = brand.washTop
    static let brandBackgroundMid = brand.washBottom
    static let brandBackgroundBottom = brand.washBottom

    static let brandRed = brand.deep
    static let brandRedDark = brand.deepShadow
    static let ctaGradient = LinearGradient(
        colors: [brand.deep, brand.barTop],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Text

    static let textPrimary = Color(hex: "1C2B3A")
    static let textSecondary = slateGray
    static let textMuted = silver

    // MARK: - Fields

    static let fieldBackground = whiteSmoke
    static let fieldBorder = gainsboro
    static let fieldDivider = gainsboro

    // MARK: - Home

    static let homeCanvas = Color.white
    static let homeHeaderTop = brand.deep
    static let homeHeaderBottom = brand.barTop
    static let imageTile = brand.imageTile
}
