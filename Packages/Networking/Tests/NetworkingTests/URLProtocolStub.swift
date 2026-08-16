import Foundation

/// `URLSession` 을 가로채는 가짜 서버. Alamofire 도 URLSession 위에 있으므로 그대로 동작한다.
///
/// `URLProtocol` 은 타입 단위로 등록되므로 stub 을 static 으로 두면 테스트끼리 간섭한다.
/// 그래서 **세션마다 고유 id 를 발급하고 요청 헤더로 자기 stub 을 찾는다** — 테스트를 병렬로 돌려도 안전하다.
final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    struct Stub {
        var statusCode: Int = 200
        var body: Data = Data()
        var headers: [String: String] = ["Content-Type": "application/json"]
        var error: Error?
        /// 응답을 보류하고 요청이 나갔다는 사실만 기록한다.
        /// "비행 중 취소"처럼 응답 대기 상태를 재현할 때 쓴다.
        var suspends: Bool = false
    }

    /// 한 테스트가 자기 stub 을 읽고 쓰는 창구.
    final class Handle: @unchecked Sendable {
        let id: String

        init(id: String) { self.id = id }

        var stub: Stub {
            get { registry.stub(for: id) }
            set { registry.setStub(newValue, for: id) }
        }

        /// 요청마다 순서대로 돌려줄 응답. 재시도가 **성공하는** 경로를 검증하려면 필요하다
        /// (1차 503 → 2차 200). 큐가 비면 `stub` 으로 돌아간다.
        func enqueue(_ stubs: [Stub]) {
            registry.enqueue(stubs, for: id)
        }

        /// 이 세션으로 나간 요청만 기록된다.
        var recorded: [URLRequest] { registry.recorded(for: id) }

        /// `stopLoading` 이 불린 횟수. 취소가 실제로 전송 계층까지 닿았는지 확인한다.
        var cancellations: Int { registry.cancellations(for: id) }

        deinit { registry.remove(id) }
    }

    private static let header = "X-Stub-Session"
    private static let registry = Registry()

    /// stub 을 끼운 세션 설정과, 그 세션 전용 창구를 함께 돌려준다.
    /// 설정에 세션 id 를 헤더로 심어 두므로 호출부가 매번 헤더를 넘기지 않아도 된다.
    static func makeSession() -> (configuration: URLSessionConfiguration, handle: Handle) {
        let id = UUID().uuidString
        registry.setStub(Stub(), for: id)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        configuration.httpAdditionalHeaders = [header: id]
        return (configuration, Handle(id: id))
    }

    // MARK: - URLProtocol

    override class func canInit(with request: URLRequest) -> Bool {
        request.value(forHTTPHeaderField: header) != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let id = request.value(forHTTPHeaderField: Self.header) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        // httpBody 는 URLProtocol 을 거치며 스트림으로 바뀌므로 여기서 되살려 기록한다.
        var recordedRequest = request
        if recordedRequest.httpBody == nil, let stream = request.httpBodyStream {
            recordedRequest.httpBody = Self.readAll(stream)
        }
        Self.registry.record(recordedRequest, for: id)

        let stub = Self.registry.next(for: id)
        // 보류 모드: 응답을 만들지 않고 멈춘다. 취소되면 stopLoading 이 불린다.
        if stub.suspends { return }
        if let error = stub.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: stub.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: stub.headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
        guard let id = request.value(forHTTPHeaderField: Self.header) else { return }
        Self.registry.recordCancellation(for: id)
    }

    private static func readAll(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        let size = 4096
        var buffer = [UInt8](repeating: 0, count: size)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: size)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }

    /// 세션 id 별 stub·기록 보관소. 여러 스레드에서 동시에 들어오므로 잠금으로 보호한다.
    private final class Registry: @unchecked Sendable {
        private let lock = NSLock()
        private var stubs: [String: Stub] = [:]
        private var queued: [String: [Stub]] = [:]
        private var records: [String: [URLRequest]] = [:]
        private var cancels: [String: Int] = [:]

        func stub(for id: String) -> Stub {
            lock.withLock { stubs[id] ?? Stub() }
        }

        func enqueue(_ newStubs: [Stub], for id: String) {
            lock.withLock { queued[id] = newStubs }
        }

        /// 큐가 있으면 앞에서 하나 꺼내고, 없으면 고정 stub 을 돌려준다.
        func next(for id: String) -> Stub {
            lock.withLock {
                if var pending = queued[id], !pending.isEmpty {
                    let head = pending.removeFirst()
                    queued[id] = pending
                    return head
                }
                return stubs[id] ?? Stub()
            }
        }

        func setStub(_ stub: Stub, for id: String) {
            lock.withLock { stubs[id] = stub }
        }

        func record(_ request: URLRequest, for id: String) {
            lock.withLock { records[id, default: []].append(request) }
        }

        func recorded(for id: String) -> [URLRequest] {
            lock.withLock { records[id] ?? [] }
        }

        func recordCancellation(for id: String) {
            lock.withLock { cancels[id, default: 0] += 1 }
        }

        func cancellations(for id: String) -> Int {
            lock.withLock { cancels[id] ?? 0 }
        }

        func remove(_ id: String) {
            lock.withLock {
                stubs[id] = nil
                queued[id] = nil
                records[id] = nil
                cancels[id] = nil
            }
        }
    }
}
