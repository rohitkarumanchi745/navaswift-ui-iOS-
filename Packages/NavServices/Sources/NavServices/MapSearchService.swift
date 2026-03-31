import Foundation
import NavCore
import NavNetworking

@MainActor
public class MapSearchService: ObservableObject {

    // MARK: - Published State

    @Published public var trendingPlaces: [TrendingPlace] = []
    @Published public var explorerInterests: ExplorerInterestsResponse?
    @Published public var isLoadingTrending = false

    // MARK: - Init

    public init() {}

    // MARK: - Track Search (POST /map/search)

    /// Fire-and-forget: logs a map search/interaction to the backend.
    public func trackSearch(
        query: String? = nil,
        latitude: Double,
        longitude: Double,
        placeId: String? = nil,
        placeName: String? = nil,
        category: String? = nil,
        navigated: Bool = false
    ) {
        Task {
            do {
                var body: [String: Any] = [
                    "latitude": latitude,
                    "longitude": longitude,
                    "navigated": navigated,
                ]
                if let query { body["query"] = query }
                if let placeId { body["place_id"] = placeId }
                if let placeName { body["place_name"] = placeName }
                if let category { body["category"] = category }

                let _: MapSearchResponse = try await APIService.shared.post(
                    path: "/map/search",
                    body: body
                )
                NavLog.debug("Map search tracked: \(placeName ?? query ?? "(\(latitude),\(longitude))")", category: .general)
            } catch {
                // Fire-and-forget — don't block UI on failure
                NavLog.debug("Map search track failed: \(error.localizedDescription)", category: .network)
            }
        }
    }

    // MARK: - Trending Places (GET /map/trending)

    public func fetchTrending(latitude: Double, longitude: Double) async {
        isLoadingTrending = true
        defer { isLoadingTrending = false }

        do {
            let response: MapTrendingResponse = try await APIService.shared.get(
                path: "/map/trending?lat=\(latitude)&lng=\(longitude)"
            )
            trendingPlaces = response.places
            NavLog.debug("Fetched \(response.places.count) trending places", category: .general)
        } catch {
            NavLog.debug("Trending places fetch failed: \(error.localizedDescription)", category: .network)
        }
    }

    // MARK: - Explorer Interests (GET /map/interests)

    public func fetchExplorerInterests() async {
        do {
            let response: ExplorerInterestsResponse = try await APIService.shared.get(
                path: "/map/interests"
            )
            explorerInterests = response
            NavLog.debug("Explorer type: \(response.explorerType) \(response.explorerEmoji)", category: .general)
        } catch {
            NavLog.debug("Explorer interests fetch failed: \(error.localizedDescription)", category: .network)
        }
    }
}
