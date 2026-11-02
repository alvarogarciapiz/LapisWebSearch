import Foundation

/// Selection policy, not a legal opinion or an upstream authorization grant.
public enum SearchProviderPolicy: String, Sendable, Codable {
    /// The caller explicitly selected these services and is responsible for applicable permission.
    case explicitSelection
    /// Reject the entire registry unless every adapter declares commercial clearance with HTTPS evidence.
    /// Conditional, unverified and restricted adapters are rejected, even if they would only be fallbacks.
    case requireCommercialClearance
}

public enum CommercialUseStatus: String, Sendable, Codable {
    case commerciallyCleared, conditionallyPermitted, unverified, restricted, technicallyUnavailable
}

/// Deployment-specific, author-supplied assessment. A status declaration cannot create service rights.
/// Custom providers must cite applicable official terms or authorization; no automatic legal verification occurs.
public struct ProviderUsage: Sendable, Encodable {
    public let status: CommercialUseStatus
    public let evidence: [URL]
    /// ISO calendar date of review, when available. Consumers must recheck current terms before deployment.
    public let reviewedOn: String?

    public init(status: CommercialUseStatus, evidence: [URL] = [], reviewedOn: String? = nil) {
        self.status = status
        self.evidence = evidence
        self.reviewedOn = reviewedOn
    }

    var permitsCommercialDeployment: Bool {
        status == .commerciallyCleared && !evidence.isEmpty
            && evidence.allSatisfy {
                $0.scheme?.lowercased() == "https" && $0.host?.isEmpty == false
                    && $0.user == nil && $0.password == nil
            }
    }
}
