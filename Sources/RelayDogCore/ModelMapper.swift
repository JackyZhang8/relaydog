import Foundation

public struct ModelRewriteResult: Equatable, Sendable {
    public let body: Data
    public let originalModel: String?
    public let mappedModel: String?

    public init(body: Data, originalModel: String?, mappedModel: String?) {
        self.body = body
        self.originalModel = originalModel
        self.mappedModel = mappedModel
    }
}

public enum ModelMapper {
    public static func rewriteRequestBody(_ body: Data, mappings: [String: String]) throws -> ModelRewriteResult {
        guard !body.isEmpty else {
            return ModelRewriteResult(body: body, originalModel: nil, mappedModel: nil)
        }

        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: body)
        } catch {
            return ModelRewriteResult(body: body, originalModel: nil, mappedModel: nil)
        }

        guard var dictionary = object as? [String: Any] else {
            return ModelRewriteResult(body: body, originalModel: nil, mappedModel: nil)
        }

        guard let originalModel = dictionary["model"] as? String else {
            return ModelRewriteResult(body: body, originalModel: nil, mappedModel: nil)
        }

        guard let mappedModel = mappings[originalModel], mappedModel != originalModel else {
            return ModelRewriteResult(body: body, originalModel: originalModel, mappedModel: nil)
        }

        dictionary["model"] = mappedModel
        let rewrittenBody = try JSONSerialization.data(withJSONObject: dictionary, options: [.sortedKeys])
        return ModelRewriteResult(body: rewrittenBody, originalModel: originalModel, mappedModel: mappedModel)
    }
}
