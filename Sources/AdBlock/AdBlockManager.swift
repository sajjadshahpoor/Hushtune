import WebKit

final class AdBlockManager {
    static let shared = AdBlockManager()

    private let identifier = "com.hushtune.adblock.rules"
    private var cached: WKContentRuleList?

    func compiledRuleList(completion: @escaping (WKContentRuleList?) -> Void) {
        if let cached {
            completion(cached)
            return
        }
        guard let json = Self.loadRulesJSON() else {
            completion(nil)
            return
        }
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: identifier,
            encodedContentRuleList: json
        ) { [weak self] ruleList, error in
            if let error {
                print("Hushtune ad block compile error: \(error)")
            }
            self?.cached = ruleList
            completion(ruleList)
        }
    }

    private static func loadRulesJSON() -> String? {
        guard let url = Bundle.main.url(forResource: "adblock_rules", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
