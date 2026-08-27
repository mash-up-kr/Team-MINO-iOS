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
        /// 카메라와 별도 필드여야 한다 — `appliedCamera` 는 idle 델리게이트가 되먹임 방지용으로
        /// 덮어쓰므로, 여기에 얹으면 지도를 움직일 때마다 padding 판정이 오염된다.
        private var appliedPadding: EdgeInsets?
        /// id → 화면에 올라간 GMSMarker. 증분 적용(추가/제거/갱신)용.
        private var gmsMarkersByID: [String: GMSMarker] = [:]
        /// 스타일 → 마커 그림. 같은 방의 핀은 색이 전부 같아 대부분 한 장으로 끝난다.
        private var iconCache: [MapMarkerStyle: UIImage] = [:]

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
                apply(marker.style, to: existing)
            }
            for marker in diff.inserted {
                let gmsMarker = GMSMarker(position: marker.coordinate.clCoordinate)
                gmsMarker.title = marker.title
                gmsMarker.userData = marker.id   // 델리게이트에서 id 회수용
                apply(marker.style, to: gmsMarker)
                gmsMarker.map = mapView
                gmsMarkersByID[marker.id] = gmsMarker
            }
        }

        /// 선택 마커는 다른 마커보다 위에 그린다 — 핀이 겹쳐 있을 때 방금 고른 것이 뒤로 숨으면 안 된다.
        private func apply(_ style: MapMarkerStyle, to gmsMarker: GMSMarker) {
            gmsMarker.icon = icon(for: style)
            // 그림마다 뾰족한 끝의 위치가 달라 앵커도 함께 바꾼다 — 안 바꾸면 선택할 때 핀이 튄다.
            gmsMarker.groundAnchor = MarkerIcon.groundAnchor(for: style)
            gmsMarker.zIndex = style.isSelected ? 1 : 0
        }

        /// 같은 스타일이면 그림을 재사용한다 — 핀이 수십 개면 마커마다 래스터라이즈가 반복된다.
        private func icon(for style: MapMarkerStyle) -> UIImage? {
            if let cached = iconCache[style] { return cached }
            let image = MarkerIcon.image(for: style)
            iconCache[style] = image
            return image
        }

        func apply(camera: MapCamera, to mapView: GMSMapView) {
            guard camera != appliedCamera else { return }
            switch camera {
            case .position(let position):
                appliedCamera = camera
                // 코드 주도 이동은 부드럽게 애니메이션 (즉시 점프가 필요해지면 MapCameraPosition 에 옵션 추가)
                mapView.animate(to: position.gmsCameraPosition)

            case .fit(let coordinates, let padding):
                // 크기가 0 이면 SDK 가 맞출 화면이 없어 계산이 무의미하다. appliedCamera 를
                // 기록하지 않고 넘겨 레이아웃이 잡힌 다음 업데이트에서 다시 시도하게 둔다.
                guard let bounds = coordinates.gmsBounds, mapView.bounds.size != .zero else { return }
                appliedCamera = camera
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

/// `MapMarkerStyle` → 마커 그림과 앵커. 시안(Figma `004-1-1 방 상세 peek` / `005-1 half`)의
/// 두 아이콘을 그린다.
///
/// - **비선택(아이콘 1)**: 흰 몸통 + 방 색 원 + 회색 마스코트. 색이 들어가는 자리가 원 하나뿐이라
///   몸통·마스코트만 에셋으로 두고 원은 코드에서 칠한다 — 한 장짜리 그림으로는 방마다 색을 못 바꾼다.
/// - **선택(아이콘 2)**: 검정 마스코트 머리 + 흰 눈. 시안이 방 색과 무관한 고정색이라 통짜 에셋이다.
///   (`MapMarkerStyle.tint` 는 이 상태에서 쓰이지 않는다 — 자세한 근거는 `MapMarkerStyle.tint` 주석)
private enum MarkerIcon {
    /// 비선택 핀 캔버스(시안 48 × 52.5755). 몸통·마스코트 에셋이 같은 캔버스라 그대로 겹친다.
    private static let defaultSize = CGSize(width: 48, height: 52.5755)

    /// 방 색이 들어가는 원 — 시안 `Ellipse 512`(cx 24, cy 20, r 15.545).
    private static let colorWell = CGRect(
        x: 24 - 15.545, y: 20 - 15.545,
        width: 15.545 * 2, height: 15.545 * 2
    )

    /// 마스코트 실루엣 색(시안 `#8A8A8A`). 방 색이 바뀌어도 이 회색은 그대로다.
    private static let mascotColor = UIColor(white: 0x8A / 255, alpha: 1)

    /// 몸통 그림자 — 시안 `filter0_dd` 의 두 겹. `stdDeviation` 은 CoreGraphics blur 로 환산해 2배다.
    private static let shadows: [(dy: CGFloat, blur: CGFloat)] = [(4, 6), (2, 4)]
    private static let shadowColor = UIColor(white: 0.0901961, alpha: 0.06).cgColor

    static func image(for style: MapMarkerStyle) -> UIImage? {
        style.isSelected ? asset("mapPinSelected") : unselected(tint: UIColor(style.tint))
    }

    /// 핀의 뾰족한 끝이 좌표를 가리키게 하는 앵커(그림 안에서 끝점이 놓인 비율).
    /// 두 그림의 끝점 위치가 달라 선택 전환 때 함께 바꿔 줘야 핀이 제자리에 선다.
    static func groundAnchor(for style: MapMarkerStyle) -> CGPoint {
        // 비선택: (24, 43.58) / 48 × 52.5755, 선택: (27.36, 60.18) / 55.8 × 60.8 (테두리 절반 포함)
        style.isSelected ? CGPoint(x: 0.490, y: 0.990) : CGPoint(x: 0.5, y: 0.829)
    }

    private static func unselected(tint: UIColor) -> UIImage? {
        guard let body = asset("mapPinBody"), let mascot = asset("mapPinMascot") else { return nil }
        let rect = CGRect(origin: .zero, size: defaultSize)
        return UIGraphicsImageRenderer(size: defaultSize).image { context in
            for shadow in shadows {
                context.cgContext.saveGState()
                context.cgContext.setShadow(
                    offset: CGSize(width: 0, height: shadow.dy),
                    blur: shadow.blur,
                    color: shadowColor
                )
                body.draw(in: rect)
                context.cgContext.restoreGState()
            }
            body.draw(in: rect)
            tint.setFill()
            context.cgContext.fillEllipse(in: colorWell)
            mascot.withTintColor(mascotColor, renderingMode: .alwaysOriginal).draw(in: rect)
        }
    }

    private static func asset(_ name: String) -> UIImage? {
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
