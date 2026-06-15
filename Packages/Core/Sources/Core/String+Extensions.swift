import Foundation

public extension String {
    /// 앞뒤 공백·개행을 제거한 문자열
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 공백만 있거나 비어 있으면 nil, 그렇지 않으면 원본
    var nilIfEmpty: String? {
        trimmed.isEmpty ? nil : self
    }
}
