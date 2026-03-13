import Foundation

// MARK: - Student Verification Method

public enum StudentVerificationMethod: String, CaseIterable, Identifiable {
    case eduEmail = "edu_email"
    case studentId = "student_id"
    case enrollmentDoc = "enrollment_doc"
    case instituteDomain = "institute_domain"
    case campusEvent = "campus_event"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .eduEmail: return ".edu Email"
        case .studentId: return "Student ID + Selfie"
        case .enrollmentDoc: return "Enrollment Proof"
        case .instituteDomain: return "Institute Email"
        case .campusEvent: return "Campus Event"
        }
    }

    public var subtitle: String {
        switch self {
        case .eduEmail: return "Verify with your .edu email address"
        case .studentId: return "Photo of student ID + liveness selfie"
        case .enrollmentDoc: return "Upload enrollment letter or fee receipt"
        case .instituteDomain: return "Verify with your institute email domain"
        case .campusEvent: return "Scan QR at campus verification booth"
        }
    }

    public var icon: String {
        switch self {
        case .eduEmail: return "envelope.fill"
        case .studentId: return "person.text.rectangle.fill"
        case .enrollmentDoc: return "doc.text.fill"
        case .instituteDomain: return "building.2.fill"
        case .campusEvent: return "qrcode.viewfinder"
        }
    }

    /// Assurance level displayed on badge
    public var badgeLabel: String {
        switch self {
        case .eduEmail: return "Verified by email"
        case .studentId: return "Verified by document"
        case .enrollmentDoc: return "Verified by document"
        case .instituteDomain: return "Verified by email"
        case .campusEvent: return "Verified in person"
        }
    }
}

// MARK: - Verification Status Response

public struct StudentVerificationStatusResponse: Codable {
    public let isVerified: Bool?
    public let method: String?
    public let universityName: String?
    public let email: String?
    public let status: String?  // "pending_review", "approved", "rejected"
    public let reviewMessage: String?

    enum CodingKeys: String, CodingKey {
        case isVerified = "is_verified"
        case method
        case universityName = "university_name"
        case email
        case status
        case reviewMessage = "review_message"
    }
}

// MARK: - Document Upload Response

public struct DocumentVerificationResponse: Codable {
    public let submitted: Bool?
    public let status: String?  // "pending_review", "auto_approved", "rejected"
    public let confidence: Double?
    public let universityName: String?
    public let validUntil: String?
    public let message: String?

    enum CodingKeys: String, CodingKey {
        case submitted, status, confidence, message
        case universityName = "university_name"
        case validUntil = "valid_until"
    }
}

// MARK: - Student ID + Selfie Response

public struct StudentIDVerificationResponse: Codable {
    public let submitted: Bool?
    public let status: String?
    public let idConfidence: Double?
    public let faceMatchConfidence: Double?
    public let universityName: String?
    public let nameOnId: String?
    public let validityYear: String?
    public let message: String?

    enum CodingKeys: String, CodingKey {
        case submitted, status, message
        case idConfidence = "id_confidence"
        case faceMatchConfidence = "face_match_confidence"
        case universityName = "university_name"
        case nameOnId = "name_on_id"
        case validityYear = "validity_year"
    }
}

// MARK: - Campus Event Verification Response

public struct CampusEventVerificationResponse: Codable {
    public let verified: Bool?
    public let eventName: String?
    public let universityName: String?
    public let message: String?

    enum CodingKeys: String, CodingKey {
        case verified, message
        case eventName = "event_name"
        case universityName = "university_name"
    }
}

// MARK: - Institute Domain

public struct InstituteDomain: Codable, Identifiable {
    public let id: String
    public let domain: String
    public let instituteName: String
    public let country: String?

    enum CodingKeys: String, CodingKey {
        case id, domain, country
        case instituteName = "institute_name"
    }
}

public struct InstituteDomainSearchResponse: Codable {
    public let domains: [InstituteDomain]
}
