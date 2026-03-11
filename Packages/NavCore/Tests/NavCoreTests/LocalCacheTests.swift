import Testing
import Foundation
@testable import NavCore

@Suite("LocalCache", .serialized)
struct LocalCacheTests {

    // MARK: - Round-Trip

    @Test("Save and load round-trips Codable data")
    func saveAndLoad() {
        let profiles = [
            DiscoverProfile(id: "1", name: "Alice", age: 25),
            DiscoverProfile(id: "2", name: "Bob", age: 28),
        ]
        LocalCache.shared.save(profiles, forKey: .discoverFeed)
        let loaded = LocalCache.shared.load([DiscoverProfile].self, forKey: .discoverFeed, maxAge: 60)
        #expect(loaded != nil)
        #expect(loaded?.count == 2)
        #expect(loaded?.first?.name == "Alice")

        // Cleanup
        LocalCache.shared.remove(forKey: .discoverFeed)
    }

    @Test("Save and load MatchProfile round-trips correctly")
    func matchProfileRoundTrip() {
        let matches = [
            MatchProfile(id: "m1", matchId: "match1", name: "Priya", age: 24, photo: "photo.jpg"),
        ]
        LocalCache.shared.save(matches, forKey: .conversations)
        let loaded = LocalCache.shared.load([MatchProfile].self, forKey: .conversations, maxAge: 60)
        #expect(loaded != nil)
        #expect(loaded?.first?.name == "Priya")
        #expect(loaded?.first?.matchId == "match1")

        LocalCache.shared.remove(forKey: .conversations)
    }

    // MARK: - Staleness

    @Test("Load returns nil when data is older than maxAge")
    func staleData() {
        let data = ["test_value"]
        LocalCache.shared.save(data, forKey: .matches)

        // With maxAge of 0 seconds, data should be stale immediately
        let loaded = LocalCache.shared.load([String].self, forKey: .matches, maxAge: 0)
        #expect(loaded == nil)

        LocalCache.shared.remove(forKey: .matches)
    }

    @Test("loadStale returns data regardless of age")
    func loadStaleIgnoresAge() {
        let data = ["stale_ok"]
        LocalCache.shared.save(data, forKey: .matches)

        // Even though data would be "stale" by any maxAge, loadStale still returns it
        let loaded = LocalCache.shared.loadStale([String].self, forKey: .matches)
        #expect(loaded != nil)
        #expect(loaded?.first == "stale_ok")

        LocalCache.shared.remove(forKey: .matches)
    }

    // MARK: - Missing Data

    @Test("Load returns nil for non-existent key")
    func loadMissingKey() {
        LocalCache.shared.remove(forKey: .discoverFeed)
        let loaded = LocalCache.shared.load([String].self, forKey: .discoverFeed, maxAge: 3600)
        #expect(loaded == nil)
    }

    @Test("loadStale returns nil for non-existent key")
    func loadStaleMissingKey() {
        LocalCache.shared.remove(forKey: .conversations)
        let loaded = LocalCache.shared.loadStale([String].self, forKey: .conversations)
        #expect(loaded == nil)
    }

    // MARK: - Remove & Clear

    @Test("Remove deletes a specific key")
    func removeKey() {
        LocalCache.shared.save(["data"], forKey: .discoverFeed)
        LocalCache.shared.remove(forKey: .discoverFeed)
        let loaded = LocalCache.shared.loadStale([String].self, forKey: .discoverFeed)
        #expect(loaded == nil)
    }

    @Test("clearAll removes all cached data")
    func clearAll() {
        LocalCache.shared.save(["a"], forKey: .discoverFeed)
        LocalCache.shared.save(["b"], forKey: .conversations)
        LocalCache.shared.save(["c"], forKey: .matches)

        LocalCache.shared.clearAll()

        #expect(LocalCache.shared.loadStale([String].self, forKey: .discoverFeed) == nil)
        #expect(LocalCache.shared.loadStale([String].self, forKey: .conversations) == nil)
        #expect(LocalCache.shared.loadStale([String].self, forKey: .matches) == nil)
    }

    // MARK: - Type Mismatch

    @Test("Load returns nil on type mismatch")
    func typeMismatch() {
        LocalCache.shared.save(["string_data"], forKey: .discoverFeed)
        let loaded = LocalCache.shared.load([Int].self, forKey: .discoverFeed, maxAge: 3600)
        #expect(loaded == nil)

        LocalCache.shared.remove(forKey: .discoverFeed)
    }

    // MARK: - Key Rotation

    @Test("rotateKey invalidates previously cached data")
    func rotateKeyInvalidatesCache() {
        LocalCache.shared.save(["before_rotation"], forKey: .discoverFeed)
        let beforeRotation = LocalCache.shared.loadStale([String].self, forKey: .discoverFeed)
        #expect(beforeRotation != nil)

        LocalCache.shared.rotateKey()

        // After rotation, old data should be gone (clearAll wipes files)
        let afterRotation = LocalCache.shared.loadStale([String].self, forKey: .discoverFeed)
        #expect(afterRotation == nil)
    }

    @Test("Cache works normally after key rotation")
    func cacheWorksAfterRotation() {
        LocalCache.shared.rotateKey()

        // Save and load with the new key should work
        let data = ["post_rotation_data"]
        LocalCache.shared.save(data, forKey: .matches)
        let loaded = LocalCache.shared.load([String].self, forKey: .matches, maxAge: 60)
        #expect(loaded != nil)
        #expect(loaded?.first == "post_rotation_data")

        LocalCache.shared.remove(forKey: .matches)
    }

    // MARK: - Overwrite Behavior

    @Test("Saving to same key overwrites previous data")
    func overwriteKey() {
        LocalCache.shared.save(["first"], forKey: .discoverFeed)
        LocalCache.shared.save(["second"], forKey: .discoverFeed)

        let loaded = LocalCache.shared.load([String].self, forKey: .discoverFeed, maxAge: 60)
        #expect(loaded?.first == "second")

        LocalCache.shared.remove(forKey: .discoverFeed)
    }

    // MARK: - Large Data

    @Test("Cache handles large arrays without data loss")
    func largeDataRoundTrip() {
        let largeArray = (0..<500).map { DiscoverProfile(id: "\($0)", name: "User \($0)", age: 20 + ($0 % 30)) }
        LocalCache.shared.save(largeArray, forKey: .discoverFeed)
        let loaded = LocalCache.shared.load([DiscoverProfile].self, forKey: .discoverFeed, maxAge: 60)
        #expect(loaded?.count == 500)
        #expect(loaded?.last?.name == "User 499")

        LocalCache.shared.remove(forKey: .discoverFeed)
    }

    // MARK: - Independent Keys

    @Test("Different keys store independent data")
    func independentKeys() {
        LocalCache.shared.save(["feed_data"], forKey: .discoverFeed)
        LocalCache.shared.save(["conv_data"], forKey: .conversations)

        let feed = LocalCache.shared.load([String].self, forKey: .discoverFeed, maxAge: 60)
        let conv = LocalCache.shared.load([String].self, forKey: .conversations, maxAge: 60)

        #expect(feed?.first == "feed_data")
        #expect(conv?.first == "conv_data")

        // Removing one shouldn't affect the other
        LocalCache.shared.remove(forKey: .discoverFeed)
        let convAfter = LocalCache.shared.load([String].self, forKey: .conversations, maxAge: 60)
        #expect(convAfter?.first == "conv_data")

        LocalCache.shared.remove(forKey: .conversations)
    }
}
