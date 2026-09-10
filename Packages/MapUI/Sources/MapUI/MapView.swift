#if canImport(GoogleMaps)
import SwiftUI
import GoogleMaps

/// GoogleMaps `GMSMapView` 를 SwiftUI 로 감싼 브릿지. **MapUI 에서 유일하게 GoogleMaps 를 import 하는 지점.**
/// 바깥에는 순수 value type(`MapCameraPosition`/`MapMarker`)과 `onEvent` 클로저만 노출한다.
public struct MapView: UIViewRepresentable {
    private let camera: MapCamera
    private let markers: [MapMarker]
    /// 지도 위에 겹치는 UI(바텀시트 등)가 가리는 영역. 구글 로고·저작권 표시가 이 안쪽으로 밀려
    /// 가려지지 않는다 — Google Maps Platform 약관이 attribution 가림을 금지한다.
    private let padding: EdgeInsets
    private let onEvent: (MapEvent) -> Void

    public init(
        camera: MapCamera,
        markers: [MapMarker],
        padding: EdgeInsets = EdgeInsets(),
        onEvent: @escaping (MapEvent) -> Void
    ) {
        self.camera = camera
        self.markers = markers
        self.padding = padding
        self.onEvent = onEvent
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(onEvent: onEvent)
    }

    public func makeUIView(context: Context) -> GMSMapView {
        let options = GMSMapViewOptions()
        // .fit 은 뷰 크기가 있어야 계산되므로 여기서 넣을 초기 위치가 없다 —
        // 레이아웃이 잡힌 뒤 updateUIView 에서 적용된다(apply(camera:) 의 크기 가드).
        if case .position(let position) = camera {
            options.camera = position.gmsCameraPosition
        }
        let mapView = GMSMapView(options: options)
        mapView.delegate = context.coordinator
        // safe-area 를 padding 에 더하는 기본 동작을 명시로 고정한다. 호출부는 "화면 하단에서
        // 몇 pt 가 가려지는가"(safe-area 제외분)만 넘기면 되고, 이는 `MHBottomSheet` 이
        // peek 값을 `peek + safeAreaInsets.bottom` 으로 환산하는 방식과 같은 기준이다.
        mapView.paddingAdjustmentBehavior = .always
        context.coordinator.apply(markers: markers, to: mapView)
        // 초기 카메라를 appliedCamera 에도 기록 — 생성 직후 첫 updateUIView 가
        // 이미 도달한 위치로 animate(및 불필요한 didIdleAt)를 다시 일으키지 않게 한다.
        context.coordinator.apply(camera: camera, to: mapView)
        context.coordinator.apply(padding: padding, to: mapView)
        return mapView
    }

    public func updateUIView(_ mapView: GMSMapView, context: Context) {
        context.coordinator.onEvent = onEvent
        context.coordinator.apply(markers: markers, to: mapView)
        context.coordinator.apply(camera: camera, to: mapView)
        context.coordinator.apply(padding: padding, to: mapView)
    }

    /// `GMSMapViewDelegate` 를 받아 GoogleMaps 이벤트를 순수 `MapEvent` 로 변환해 밖으로 던진다.
    public final class Coordinator: NSObject, GMSMapViewDelegate {
        var onEvent: (MapEvent) -> Void

        /// 이미 적용한 마커/카메라 — 매 update 마다 불필요한 재적용(및 카메라 되먹임 루프)을 막는다.
        private var appliedMarkers: [MapMarker] = []
        private var appliedCamera: MapCamera?
        /// 마지막으로 적용한 `.fit`. `appliedCamera` 와 별도여야 한다 — 한 번 `.position` 을
        /// 적용하면(클러스터 확대) `appliedCamera` 가 그 값으로 덮여, **직전과 같은 `.fit` 이
        /// 다시 들어올 때 "다른 값" 으로 보여 재적용**된다. 그러면 확대해 둔 화면이 핀 전체를
        /// 담는 자리로 튕겨 돌아간다. 같은 fit 은 한 번만 적용한다.
        ///
        /// "같은 fit" 의 판정에는 ``MapCamera/fit(coordinates:padding:requestID:)`` 의 번호가
        /// 함께 들어간다 — 화면이 바뀌어 같은 핀을 **다시** 맞춰야 하는 경우를 호출부가
        /// 그 번호로 구별해 준다.
        private var appliedFit: MapCamera?
        /// 카메라와 별도 필드여야 한다 — `appliedCamera` 는 idle 델리게이트가 되먹임 방지용으로
        /// 덮어쓰므로, 여기에 얹으면 지도를 움직일 때마다 padding 판정이 오염된다.
        private var appliedPadding: EdgeInsets?
        /// id → 화면에 올라간 GMSMarker. 증분 적용(추가/제거/갱신)용.
        private var gmsMarkersByID: [String: GMSMarker] = [:]
        /// 스타일 → 라벨 없는 마커 그림과 앵커. 같은 방의 핀은 색이 전부 같아 대부분 한 장으로 끝난다.
        private var iconCache: [MapMarkerStyle: MarkerIcon.MarkerArt] = [:]

        init(onEvent: @escaping (MapEvent) -> Void) {
            self.onEvent = onEvent
        }

        /// id 기준 증분 적용 — 전체 clear+재생성은 유지되는 마커까지 깜빡이게 하고,
        /// clear() 가 마커 외 오버레이(폴리라인 등)까지 지우므로 쓰지 않는다.
        func apply(markers: [MapMarker], to mapView: GMSMapView) {
            guard markers != appliedMarkers else { return }
            let diff = MarkerDiff.between(applied: appliedMarkers, new: markers)
            appliedMarkers = markers

            for id in diff.removedIDs {
                gmsMarkersByID[id]?.map = nil
                gmsMarkersByID[id] = nil
            }
            for marker in diff.updated {
                guard let existing = gmsMarkersByID[marker.id] else { continue }
                existing.position = marker.coordinate.clCoordinate
                existing.title = marker.title
                apply(marker, to: existing)
            }
            for marker in diff.inserted {
                let gmsMarker = GMSMarker(position: marker.coordinate.clCoordinate)
                gmsMarker.title = marker.title
                gmsMarker.userData = marker.id   // 델리게이트에서 id 회수용
                apply(marker, to: gmsMarker)
                gmsMarker.map = mapView
                gmsMarkersByID[marker.id] = gmsMarker
            }
        }

        /// 선택 마커는 다른 마커보다 위에 그린다 — 핀이 겹쳐 있을 때 방금 고른 것이 뒤로 숨으면 안 된다.
        ///
        /// 아이콘과 앵커를 **한 값(`MarkerArt`)으로 함께** 받는다 — 라벨이 붙으면 그림이 아래로
        /// 커져 핀 끝점의 비율이 달라지므로, 둘을 따로 구하면 어긋나 핀이 좌표에서 떠 보인다.
        private func apply(_ marker: MapMarker, to gmsMarker: GMSMarker) {
            let art = MarkerIcon.art(for: marker.style, label: labelLines(of: marker), cache: &iconCache)
            gmsMarker.icon = art?.image
            // 그림을 못 만들면(에셋 누락) SDK 기본 마커가 뜬다 — 그 기본 마커의 끝점이 (0.5, 1) 이다.
            gmsMarker.groundAnchor = art?.groundAnchor ?? CGPoint(x: 0.5, y: 1)
            gmsMarker.zIndex = marker.style.isSelected ? 1 : 0
        }

        /// 마커에 그릴 라벨 줄. `title` 이 비면 라벨을 그리지 않는다 — 라벨을 보일 줌인지는
        /// 순수 계산부(`PlaceMap`)가 `title` 을 채우거나 비우는 것으로 정한다.
        ///
        /// `title` 은 GoogleMaps 기본 info window 용 값이기도 하지만 이 지도는 그것을 억제하므로
        /// (`mapView(_:didTap:)` 이 `true` 를 돌려준다) 이 값의 유일한 쓰임이 라벨이다.
        private func labelLines(of marker: MapMarker) -> [String] {
            marker.title.map(MarkerLabel.lines(for:)) ?? []
        }

        func apply(camera: MapCamera, to mapView: GMSMapView) {
            guard camera != appliedCamera else { return }
            switch camera {
            case .position(let position):
                appliedCamera = camera
                // 코드 주도 이동은 부드럽게 애니메이션 (즉시 점프가 필요해지면 MapCameraPosition 에 옵션 추가)
                mapView.animate(to: position.gmsCameraPosition)

            case .fit(let coordinates, let padding, _):
                // 이미 이 fit 으로 맞춘 적이 있으면 카메라를 건드리지 않는다 — 핀이 그대로인데
                // 다시 맞추면 그 사이 사용자가 옮기거나 확대해 둔 화면을 뺏는다.
                guard camera != appliedFit else { return }
                // 맞출 좌표가 없거나(조회 중) 크기가 0 이면(레이아웃 전) SDK 가 맞출 화면이 없다.
                // **appliedCamera·appliedFit 을 기록하지 않고** 넘겨, 좌표가 도착하거나 레이아웃이
                // 잡힌 다음 업데이트에서 다시 시도하게 둔다.
                guard let bounds = coordinates.gmsBounds, mapView.bounds.size != .zero else { return }
                appliedCamera = camera
                appliedFit = camera
                mapView.animate(with: GMSCameraUpdate.fit(bounds, withPadding: padding))
            }
        }

        func apply(padding: EdgeInsets, to mapView: GMSMapView) {
            guard padding != appliedPadding else { return }
            appliedPadding = padding
            mapView.padding = padding.uiEdgeInsets
        }

        // MARK: - GMSMapViewDelegate → MapEvent

        public func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            if let id = marker.userData as? String {
                onEvent(.didTapMarker(id: id))
            }
            return true   // 탭 UI(바텀시트 등)는 이벤트를 받은 화면이 그린다 — 기본 info window 억제
        }

        public func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            onEvent(.didTap(coordinate.mapCoordinate))
        }

        public func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
            let idle = position.mapCameraPosition
            switch appliedCamera {
            case .position, .none:
                appliedCamera = .position(idle)   // 방금 도달한 값으로 기록 → 되먹임 시 재적용 스킵
            case .fit:
                // .fit 은 덮어쓰지 않는다. 덮어쓰면 같은 fit 이 다시 들어올 때 값이 달라져
                // 재적용되고, 사용자가 손으로 옮긴 화면이 원래 자리로 튕긴다.
                break
            }
            onEvent(.didIdleAt(idle))
        }
    }
}

// MARK: - 마커 그림

/// `MapMarkerStyle` → 마커 그림과 앵커.
///
/// - **핀**: Figma `character/Pin` 아트(`Resources/MapMarkers.xcassets`, 13색 × 기본/선택 = 26장).
///   어느 색·상태인지는 ``MapMarkerColor/assetName(selected:)`` 가 정하고, 여기서는 에셋을 읽어
///   라벨을 붙이고 앵커를 잰다. 예전엔 몸통·마스코트 에셋에 방 색 원을 코드로 칠했는데, 그 조합은
///   시안의 **색 없음 배리언트**를 하드코딩한 것이라 어떤 방 색을 골라도 마스코트가 회색이었다.
/// - **클러스터**: 시안 에셋이 없어(플래그) 방 색 원 + 카운트를 코드로 그린다.
///
/// `private` 이 아닌 이유: `PlaceMapUITests/MapMarkerArtTests` 가 `@testable import` 로 에셋 26장과
/// 앵커 실측을 검증한다 — MapUI 자체 테스트는 macOS 호스트라 `UIImage` 를 만들 수 없다.
enum MarkerIcon {
    /// 그림과 앵커를 **함께** 돌려준다. 라벨이 붙으면 캔버스가 아래로 커져 핀 끝점의 비율이
    /// 달라지므로 둘을 따로 구하면 어긋나 핀이 좌표에서 떠 보인다.
    struct MarkerArt {
        let image: UIImage
        /// 좌표를 가리키는 점이 그림 안에서 놓인 비율(`GMSMarker.groundAnchor`).
        let groundAnchor: CGPoint
    }

    /// 라벨 글꼴. **시스템 폰트를 쓴다.**
    ///
    /// 두 가지 이유다. `MapUI` 는 macOS 테스트 호스트를 지원해 iOS 전용인 `DesignSystem`(SUITE)에
    /// 의존할 수 없고(`Package.swift` 주석), 장소명은 사용자가 고른 임의의 한글이라 SUITE 의 빈
    /// 글리프(~8,500 음절)를 만나면 **이름이 빈칸으로 렌더된다**(`DesignSystem/README.md` 폰트 규칙과
    /// 같은 사정 — 그 규칙이 입력 필드만 예외로 둔 것은 그때까지 임의 한글이 거기에만 있었기 때문이다).
    private static let labelFont = UIFont.systemFont(ofSize: 12, weight: .semibold)
    private static let labelColor = UIColor(white: 0.15, alpha: 1)
    /// 지도 위 어떤 색에서도 읽히도록 글자 뒤에 흰 후광을 깐다. 시안에 지정이 없어(플래그) 지도
    /// 라벨의 일반 관례를 따랐다.
    private static let labelHaloColor = UIColor.white
    private static let labelHaloWidth: CGFloat = 2
    /// 핀 아래끝과 라벨 첫 줄 사이 간격.
    private static let labelTopGap: CGFloat = 2
    private static let labelLineHeight: CGFloat = 14

    /// 클러스터 지름(시안에 지정이 없어 플래그). 기본 핀 폭 42 와 선택 핀 폭 56 사이에 잡아 두
    /// 형태가 같은 무게로 보이게 했다.
    private static let clusterSide: CGFloat = 44
    private static let clusterFont = UIFont.systemFont(ofSize: 14, weight: .bold)
    private static let clusterTextColor = UIColor(white: 0.15, alpha: 1)
    private static let clusterBorderColor = UIColor.white
    private static let clusterBorderWidth: CGFloat = 2

    /// 앵커를 잴 때 "진하다" 고 보는 알파 하한. 기본 핀 아트의 그림자(`filter`)는 이보다 훨씬
    /// 옅어 걸러지고, 본체의 안티에일리어싱 가장자리만 걸린다.
    private static let opaqueAlpha: UInt8 = 128

    static func art(
        for style: MapMarkerStyle,
        label: [String],
        cache: inout [MapMarkerStyle: MarkerArt]
    ) -> MarkerArt? {
        guard let base = baseArt(for: style, cache: &cache) else { return nil }
        // 클러스터는 라벨을 달지 않는다(어느 장소의 이름인지 정할 수 없다) — 호출부도 `title` 을
        // 비워 보내지만, 여기서도 한 번 더 막아 원 하나로 끝낸다.
        if case .cluster = style.kind { return base }
        guard !label.isEmpty else { return base }
        return composed(pin: base, label: label)
    }

    /// 라벨 없는 그림. **스타일이 같으면 재사용한다** — 핀이 수백 개면 마커마다 에셋 디코딩·앵커
    /// 측정이 반복된다. 라벨은 이름마다 달라 캐시 키에 넣지 않는다(넣으면 캐시가 이름 수만큼 늘어난다).
    private static func baseArt(
        for style: MapMarkerStyle,
        cache: inout [MapMarkerStyle: MarkerArt]
    ) -> MarkerArt? {
        if let cached = cache[style] { return cached }
        let art: MarkerArt?
        switch style.kind {
        case .pin(let color):
            art = asset(color.assetName(selected: style.isSelected)).map {
                MarkerArt(image: $0, groundAnchor: tip(of: $0))
            }
        case .cluster(let count, let tint):
            // 원의 가운데가 좌표를 가리킨다 — 핀처럼 아래로 뾰족한 끝이 없다.
            art = MarkerArt(
                image: clusterImage(count: count, tint: UIColor(tint)),
                groundAnchor: CGPoint(x: 0.5, y: 0.5)
            )
        }
        if let art { cache[style] = art }
        return art
    }

    /// 핀의 뾰족한 끝(좌표를 가리키는 점)이 그림 안에서 놓인 비율.
    ///
    /// **상수로 못 둔다** — 아트 26장이 한 캔버스 규격을 쓰지 않는다. 기본 핀은 42×48 에 끝점이
    /// (21, 42.6)이고 그 아래는 그림자 filter 자리라 비어 있다. 선택 핀은 56×61 에 끝점이 바닥(61)에
    /// 닿는데, **`cyan` 만 귀마개 때문에 폭 58 이고 끝점이 57.5 로 떠 있다.** 상태별 상수 두 개로는
    /// cyan 선택 핀이 좌표에서 3.5pt 떠 보인다.
    ///
    /// 그래서 그림을 알파 전용 비트맵에 한 번 그려 **아래에서 위로 첫 번째 진한 행**을 찾고, 그 행의
    /// 가운데를 끝점으로 삼는다. 스타일별로 한 번만 재고 캐시된다(``baseArt(for:cache:)``). 디자이너가
    /// 캔버스를 바꿔 재수출해도 스스로 맞는다. 실측값은 `PlaceMapUITests/MapMarkerArtTests` 가 고정한다.
    static func tip(of image: UIImage) -> CGPoint {
        let fallback = CGPoint(x: 0.5, y: 1)
        let scale: CGFloat = 2
        let width = Int((image.size.width * scale).rounded()), height = Int((image.size.height * scale).rounded())
        guard width > 0, height > 0 else { return fallback }

        var alpha = [UInt8](repeating: 0, count: width * height)
        let drawn = alpha.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
            ) else { return false }
            // CoreGraphics 원점은 왼쪽 아래다. 뒤집어 UIKit 좌표로 그리면 버퍼의 0번 행이 그림의 **위**다.
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: scale, y: -scale)
            UIGraphicsPushContext(context)
            image.draw(in: CGRect(origin: .zero, size: image.size))
            UIGraphicsPopContext()
            return true
        }
        guard drawn else { return fallback }

        for row in stride(from: height - 1, through: 0, by: -1) {
            let rowStart = row * width
            guard let first = (0..<width).first(where: { alpha[rowStart + $0] >= opaqueAlpha }),
                  let last = (0..<width).last(where: { alpha[rowStart + $0] >= opaqueAlpha })
            else { continue }
            return CGPoint(
                x: CGFloat(first + last + 1) / 2 / CGFloat(width),
                y: CGFloat(row + 1) / CGFloat(height)
            )
        }
        return fallback
    }

    /// 클러스터 그림 — 방 색 원 + 흰 테두리 + 카운트.
    ///
    /// **시안 에셋이 없어 근사했다(플래그).** PRD 는 `클러스터 1~99`·`클러스터 100+` 를 핀의 네
    /// 형태 중 둘로 적었지만 디자인 라이브러리에 그 컴포넌트가 없다. 값이 나오면 이 함수를
    /// 에셋 로드로 갈아끼우면 된다 — 카운트 표기 규칙은 `PlaceMap.clusterCountText` 가 갖는다.
    private static func clusterImage(count: Int, tint: UIColor) -> UIImage {
        let text = MapMarkerKind.clusterCountText(count) as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: clusterFont,
            .foregroundColor: clusterTextColor,
        ]
        // 카운트가 길면(`100+`) 원을 가로로 늘려 글자가 넘치지 않게 한다.
        let textSize = text.size(withAttributes: attributes)
        let side = max(clusterSide, textSize.width + clusterFont.pointSize)
        let canvas = CGSize(width: side.rounded(.up), height: clusterSide)

        return UIGraphicsImageRenderer(size: canvas).image { _ in
            let rect = CGRect(origin: .zero, size: canvas)
                .insetBy(dx: clusterBorderWidth / 2, dy: clusterBorderWidth / 2)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: rect.height / 2)
            tint.setFill()
            path.fill()
            clusterBorderColor.setStroke()
            path.lineWidth = clusterBorderWidth
            path.stroke()

            text.draw(
                at: CGPoint(
                    x: (canvas.width - textSize.width) / 2,
                    y: (canvas.height - textSize.height) / 2
                ),
                withAttributes: attributes
            )
        }
    }

    /// 핀 아래에 라벨을 붙인 그림. 핀은 가로 가운데에 두고 라벨은 그 아래 가운데 정렬한다.
    private static func composed(pin: MarkerArt, label: [String]) -> MarkerArt {
        let attributes: [NSAttributedString.Key: Any] = [.font: labelFont]
        let lineWidths = label.map { ($0 as NSString).size(withAttributes: attributes).width }
        let labelWidth = (lineWidths.max() ?? 0) + labelHaloWidth * 2
        let labelHeight = labelLineHeight * CGFloat(label.count)
        let pinSize = pin.image.size

        let canvas = CGSize(
            width: max(pinSize.width, labelWidth).rounded(.up),
            height: (pinSize.height + labelTopGap + labelHeight).rounded(.up)
        )
        let pinOrigin = CGPoint(x: (canvas.width - pinSize.width) / 2, y: 0)

        let composite = UIGraphicsImageRenderer(size: canvas).image { _ in
            pin.image.draw(in: CGRect(origin: pinOrigin, size: pinSize))

            for (index, line) in label.enumerated() {
                let text = line as NSString
                let width = text.size(withAttributes: attributes).width
                let origin = CGPoint(
                    x: (canvas.width - width) / 2,
                    y: pinSize.height + labelTopGap + labelLineHeight * CGFloat(index)
                )
                // 후광을 먼저 깔고 그 위에 글자를 얹는다 — 획을 두껍게 그린 뒤 덮는 방식.
                var halo = attributes
                halo[.strokeColor] = labelHaloColor
                halo[.strokeWidth] = labelHaloWidth
                halo[.foregroundColor] = labelHaloColor
                text.draw(at: origin, withAttributes: halo)

                var fill = attributes
                fill[.foregroundColor] = labelColor
                text.draw(at: origin, withAttributes: fill)
            }
        }

        // **정렬 사각형을 핀 글리프로 좁힌다.** SDK 문서(`GMSMarker.icon`): "Supports the use of
        // alignmentRectInsets to specify a reduced tap area. **This also redefines how anchors are
        // specified.**"
        //
        // 이걸 안 하면 두 가지가 깨진다. 라벨이 핀보다 넓어 **투명한 라벨 자리가 옆 핀의 탭을
        // 훔치고**(이름이 긴 장소일수록 심하다), 앵커도 캔버스 전체 기준이 되어 라벨 줄 수마다
        // 다시 계산해야 한다. 정렬 사각형을 핀 그림에 맞추면 탭 영역이 핀만 남고 앵커는 라벨이
        // 없을 때와 **같은 비율**이 된다 — 그래서 아래가 핀에서 잰 앵커 그대로다.
        let image = composite.withAlignmentRectInsets(
            UIEdgeInsets(
                top: 0,
                left: pinOrigin.x,
                bottom: canvas.height - pinSize.height,
                right: canvas.width - pinSize.width - pinOrigin.x
            )
        )
        return MarkerArt(image: image, groundAnchor: pin.groundAnchor)
    }

    /// 에셋 로드. 테스트가 같은 번들에서 같은 이름을 찾도록 한 곳에 둔다.
    static func asset(_ name: String) -> UIImage? {
        UIImage(named: name, in: .module, compatibleWith: nil)
    }
}

// MARK: - 경계 타입 변환 (GoogleMaps ↔ 순수 value type). 이 변환도 MapUI 안에만 존재한다.

private extension EdgeInsets {
    var uiEdgeInsets: UIEdgeInsets {
        UIEdgeInsets(top: top, left: leading, bottom: bottom, right: trailing)
    }
}

private extension MapCoordinate {
    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private extension Array where Element == MapCoordinate {
    /// 좌표를 모두 감싸는 사각형. 비어 있으면 `nil`.
    /// 좌표가 하나면 넓이 0 인 bounds 가 되는데, SDK 가 그 경우 최대 줌으로 맞춰 준다.
    var gmsBounds: GMSCoordinateBounds? {
        guard let first else { return nil }
        return dropFirst().reduce(GMSCoordinateBounds(coordinate: first.clCoordinate, coordinate: first.clCoordinate)) {
            $0.includingCoordinate($1.clCoordinate)
        }
    }
}

private extension MapCameraPosition {
    var gmsCameraPosition: GMSCameraPosition {
        GMSCameraPosition(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            zoom: zoom
        )
    }
}

private extension CLLocationCoordinate2D {
    var mapCoordinate: MapCoordinate {
        MapCoordinate(latitude: latitude, longitude: longitude)
    }
}

private extension GMSCameraPosition {
    var mapCameraPosition: MapCameraPosition {
        MapCameraPosition(
            coordinate: MapCoordinate(latitude: target.latitude, longitude: target.longitude),
            zoom: zoom
        )
    }
}
#endif
