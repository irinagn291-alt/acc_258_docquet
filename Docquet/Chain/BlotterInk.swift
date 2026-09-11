import SwiftUI

/// Role: Chain. Named colours and SF Pro. Hex lives only here: #F7FCF3 #FEFEFD #263918 #65C322 #5C7C46.
enum BlotterInk {
    static let face = "SF Pro"

    enum Hex {
        static let background = "#F7FCF3"
        static let surface = "#FEFEFD"
        static let ink = "#263918"
        static let accent = "#65C322"
        static let muted = "#5C7C46"
    }

    enum Palette {
        static let background = Color("background")
        static let surface = Color("surface")
        static let ink = Color("ink")
        static let accent = Color("dcqAccent")
        static let muted = Color("muted")
    }
}
