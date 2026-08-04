import SwiftUI

/// Figma `Icon/Normal/*` 아이콘. `Image(_:)` 또는 `.image`로 SwiftUI `Image`를 만든다.
public enum MHIcon: String, CaseIterable, Sendable {
    case aiReview
    case arrowDown
    case arrowDownThick
    case arrowLeft
    case arrowLeftThick
    case arrowRight
    case arrowRightThick
    case arrowUp
    case arrowUpThick
    case bell
    case bellFill
    case blank
    case bookmark
    case bookmarkFill
    case bubble
    case bubbleFill
    case caretDown
    case caretUp
    case check
    case checkThick
    case circleCheck
    case circleCheckFill
    case circleClose
    case circleExclamation
    case circleExclamationFill
    case circleInfo
    case circleInfoFill
    case circleQuestion
    case circleQuestionFill
    case close
    case closeThick
    case coffee
    case coffeeFill
    case compass
    case compassFill
    case copy
    case document
    case documentFill
    case documentText
    case documentTextFill
    case download
    case externalLink
    case eye
    case eyeFill
    case eyeSlash
    case eyeSlashFill
    case faceSmile
    case faceSmileFill
    case folder
    case folderFill
    case history
    case home
    case homeFill
    case image
    case inbox
    case keyboard
    case link
    case list
    case listCategory
    case listOrdered
    case location
    case locationFill
    case logoApple
    case logoBrunch
    case logoFacebook
    case logoGooglePlay
    case logoInstagram
    case logoKakao
    case logoLinkedIn
    case logoMicrosoft
    case logoNaverBlog
    case logoX
    case logoYoutube
    case mail
    case mailOpen
    case menu
    case menuThick
    case moreHorizontal
    case moreVertical
    case moreVerticalTight
    case pencil
    case pencilFill
    case person
    case personCircleFill
    case personFill
    case personPlus
    case personPlusFill
    case persons
    case personsFill
    case phone
    case phoneFill
    case pin
    case pinFill
    case plus
    case plusThick
    case refresh
    case reset
    case search
    case searchThick
    case send
    case sendFill
    case setting
    case share
    case shareIos
    case squareCaret
    case squareCheck
    case squarePlus
    case squarePlusFill
    case star
    case starFill
    case sun
    case thumbnail
    case trash
    case tune
    case upload
    case write
}

public extension MHIcon {
    /// 이 아이콘의 SwiftUI `Image`. 템플릿 렌더링이라 `.foregroundStyle`로 틴트된다.
    var image: Image { Image(self) }
}

public extension Image {
    /// Figma `Icon/Normal/*` 단색 아이콘을 로드한다. 템플릿 렌더링이라 `.foregroundStyle`로 틴트된다.
    init(_ icon: MHIcon) {
        self.init(icon.rawValue, bundle: .module)
    }
}
