#if canImport(GoogleMaps)
import SwiftUI
import GoogleMaps

/// GoogleMaps `GMSMapView` 를 SwiftUI 로 감싼 브릿지. **MapUI 에서 유일하게 GoogleMaps 를 import 하는 지점.**
/// 바깥에는 순수 value type(`MapCameraPosition`/`MapMarker`)과 `onEvent` 클로저만 노출한다.
public struct MapView: UIViewRepresentable {
    private let camera: MapCameraPosition
    private let markers: [MapMarker]
    /// 지도 위에 겹치는 UI(바텀시트 등)가 가리는 영역. 구글 로고·저작권 표시가 이 안쪽으로 밀려
    /// 가려지지 않는다 — Google Maps Platform 약관이 attribution 가림을 금지한다.
    private let padding: EdgeInsets
    private let onEvent: (MapEvent) -> Void

    public init(
        camera: MapCameraPosition,
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
        options.camera = camera.gmsCameraPosition
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
        private var appliedCamera: MapCameraPosition?
        /// 카메라와 별도 필드여야 한다 — `appliedCamera` 는 idle 델리게이트가 되먹임 방지용으로
        /// 덮어쓰므로, 여기에 얹으면 지도를 움직일 때마다 padding 판정이 오염된다.
        private var appliedPadding: EdgeInsets?
        /// id → 화면에 올라간 GMSMarker. 증분 적용(추가/제거/갱신)용.
        private var gmsMarkersByID: [String: GMSMarker] = [:]

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
            }
            for marker in diff.inserted {
                let gmsMarker = GMSMarker(position: marker.coordinate.clCoordinate)
                gmsMarker.title = marker.title
                gmsMarker.userData = marker.id   // 델리게이트에서 id 회수용
                gmsMarker.map = mapView
                gmsMarkersByID[marker.id] = gmsMarker
            }
        }

        func apply(camera: MapCameraPosition, to mapView: GMSMapView) {
            guard camera != appliedCamera else { return }
            appliedCamera = camera
            // 코드 주도 이동은 부드럽게 애니메이션 (즉시 점프가 필요해지면 MapCameraPosition 에 옵션 추가)
            mapView.animate(to: camera.gmsCameraPosition)
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
            // 되먹임 방지: 방금 코드로 적용한 카메라와 같으면 이벤트를 흘리지 않는다.
            let idle = position.mapCameraPosition
            appliedCamera = idle   // 방금 적용한 값으로 기록 → 되먹임 시 재적용 스킵
            onEvent(.didIdleAt(idle))
        }
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
