import Testing
@testable import NavCore

@Suite("DeepLink Parsing")
struct DeepLinkTests {

    // MARK: - Message Notifications

    @Test("Message notification with match_id → .chat(matchId:)")
    func messageWithMatchId() {
        let userInfo: [AnyHashable: Any] = ["type": "message", "match_id": "abc-123"]
        let result = DeepLink.from(userInfo: userInfo)
        #expect(result == .chat(matchId: "abc-123"))
    }

    @Test("Message notification without match_id → .chat(matchId: empty)")
    func messageWithoutMatchId() {
        let userInfo: [AnyHashable: Any] = ["type": "message"]
        let result = DeepLink.from(userInfo: userInfo)
        #expect(result == .chat(matchId: ""))
    }

    @Test("Read receipt notification → .chat(matchId:)")
    func readReceipt() {
        let userInfo: [AnyHashable: Any] = ["type": "read_receipt", "match_id": "m-99"]
        let result = DeepLink.from(userInfo: userInfo)
        #expect(result == .chat(matchId: "m-99"))
    }

    // MARK: - Match/Like Notifications

    @Test("Match notification with match_id → .matchDetail(matchId:)")
    func matchWithId() {
        let userInfo: [AnyHashable: Any] = ["type": "match", "match_id": "match-42"]
        let result = DeepLink.from(userInfo: userInfo)
        #expect(result == .matchDetail(matchId: "match-42"))
    }

    @Test("Like notification without match_id → .matches")
    func likeWithoutMatchId() {
        let userInfo: [AnyHashable: Any] = ["type": "like"]
        let result = DeepLink.from(userInfo: userInfo)
        #expect(result == .matches)
    }

    @Test("Super like notification with match_id → .matchDetail(matchId:)")
    func superLikeWithMatchId() {
        let userInfo: [AnyHashable: Any] = ["type": "super_like", "match_id": "sl-7"]
        let result = DeepLink.from(userInfo: userInfo)
        #expect(result == .matchDetail(matchId: "sl-7"))
    }

    // MARK: - Reel Message Notifications

    @Test("Reel message notification → .reelMessage(reelId:senderId:)")
    func reelMessage() {
        let userInfo: [AnyHashable: Any] = ["type": "reel_message", "reel_id": "r-5", "sender_id": "u-10"]
        let result = DeepLink.from(userInfo: userInfo)
        #expect(result == .reelMessage(reelId: "r-5", senderId: "u-10"))
    }

    @Test("Reel message deep link maps to tab 0 (Discover)")
    func reelMessageTabIndex() {
        #expect(DeepLink.reelMessage(reelId: "r-1", senderId: "u-1").tabIndex == 0)
    }

    // MARK: - Unknown / Missing Types

    @Test("Unknown notification type → nil")
    func unknownType() {
        let userInfo: [AnyHashable: Any] = ["type": "promo_offer"]
        let result = DeepLink.from(userInfo: userInfo)
        #expect(result == nil)
    }

    @Test("Empty userInfo → nil")
    func emptyPayload() {
        let result = DeepLink.from(userInfo: [:])
        #expect(result == nil)
    }

    @Test("Missing type key → nil")
    func missingTypeKey() {
        let userInfo: [AnyHashable: Any] = ["match_id": "m-1"]
        let result = DeepLink.from(userInfo: userInfo)
        #expect(result == nil)
    }

    // MARK: - Tab Index Mapping

    @Test("Chat deep link maps to tab 3")
    func chatTabIndex() {
        #expect(DeepLink.chat(matchId: "x").tabIndex == 3)
    }

    @Test("Matches deep link maps to tab 2")
    func matchesTabIndex() {
        #expect(DeepLink.matches.tabIndex == 2)
    }

    @Test("Match detail deep link maps to tab 2")
    func matchDetailTabIndex() {
        #expect(DeepLink.matchDetail(matchId: "x").tabIndex == 2)
    }

    @Test("Reels deep link maps to tab 0 (Discover)")
    func reelsTabIndex() {
        #expect(DeepLink.reels.tabIndex == 0)
    }

    @Test("Profile deep link maps to tab 4")
    func profileTabIndex() {
        #expect(DeepLink.profile.tabIndex == 4)
    }
}
