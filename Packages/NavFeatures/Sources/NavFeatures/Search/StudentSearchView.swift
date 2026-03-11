import SwiftUI
import NavCore
import NavNetworking
import NavServices

struct StudentSearchView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var storeKit: StoreKitManager
    @State private var searchText = ""
    @State private var debouncedSearch = ""
    @State private var filters = StudentFilters()
    @State private var students: [StudentResult] = []
    @State private var suggestions: SearchSuggestions?
    @State private var totalResults = 0
    @State private var offset = 0
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var showFilters = false
    @State private var showPremium = false
    @State private var errorMessage: String?
    @State private var animateOrbs = false
    @State private var showAutoComplete = false
    @State private var apiUniversities: [String] = []
    @State private var universitySearchTask: Task<Void, Never>?
    @State private var debounceTask: Task<Void, Never>?
    @FocusState private var isSearchFocused: Bool

    private var isSearchActive: Bool {
        !debouncedSearch.isEmpty || filters.hasActive
    }

    /// University names matching current search text for autocomplete
    /// Combines local trending list + API search results, deduplicated
    private var matchingUniversities: [String] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let query = searchText.lowercased()
        let trendingMatches = (suggestions?.trendingUniversities?.map(\.name) ?? [])
            .filter { $0.lowercased().contains(query) }
        // Merge: trending first, then API results not already present
        var seen = Set(trendingMatches.map { $0.lowercased() })
        var combined = trendingMatches
        for uni in apiUniversities {
            let key = uni.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                combined.append(uni)
            }
        }
        return combined
    }

    /// Students grouped by university, sorted alphabetically with "Other" last
    private var groupedStudents: [(university: String, students: [StudentResult])] {
        let grouped = Dictionary(grouping: students) { $0.university ?? "Other" }
        return grouped.sorted { lhs, rhs in
            if lhs.key == "Other" { return false }
            if rhs.key == "Other" { return true }
            return lhs.key < rhs.key
        }
        .map { (university: $0.key, students: $0.value) }
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(hex: "1A1B2E"), Color(hex: "2D1B4E"), Color(hex: "1A1B2E")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Floating orbs
            Circle()
                .fill(Color(hex: "9B7FCA").opacity(0.1))
                .frame(width: 200, height: 200)
                .blur(radius: 60)
                .offset(x: -80, y: animateOrbs ? -250 : -210)

            Circle()
                .fill(Color(hex: "A8D8EA").opacity(0.06))
                .frame(width: 160, height: 160)
                .blur(radius: 50)
                .offset(x: 100, y: animateOrbs ? 280 : 240)

            VStack(spacing: 0) {
                // Header
                headerSection

                // Search bar + autocomplete
                ZStack(alignment: .top) {
                    VStack(spacing: 0) {
                        searchBarSection
                        filterChipsSection
                    }

                    // Autocomplete dropdown
                    if showAutoComplete && !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                        autoCompleteDropdown
                            .padding(.top, 52) // below the search bar
                            .zIndex(10)
                    }
                }

                // Content
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if isSearchActive {
                            groupedResultsSection
                        } else {
                            suggestionsSection
                        }
                    }
                }
                .refreshable {
                    if isSearchActive {
                        await performSearch(reset: true)
                    } else {
                        await loadSuggestions()
                    }
                }
                .onTapGesture {
                    showAutoComplete = false
                    isSearchFocused = false
                }
            }
        }
        .navigationBarHidden(true)
        .task { await loadSuggestions() }
        .task(id: debouncedSearch) {
            if isSearchActive {
                await performSearch(reset: true)
            }
        }
        .onChange(of: searchText) { _, newValue in
            // Show autocomplete while typing
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            showAutoComplete = !trimmed.isEmpty
            // Cancel previous debounce tasks
            debounceTask?.cancel()
            universitySearchTask?.cancel()
            // Debounce 300ms for student search
            debounceTask = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                debouncedSearch = newValue
            }
            // Debounce university autocomplete API search
            if trimmed.count >= 2 {
                universitySearchTask = Task {
                    try? await Task.sleep(for: .milliseconds(250))
                    guard !Task.isCancelled else { return }
                    await searchUniversitiesForAutocomplete(query: trimmed)
                }
            } else {
                apiUniversities = []
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                animateOrbs = true
            }
        }
        .sheet(isPresented: $showFilters) {
            StudentFilterSheet(filters: $filters) {
                Task { await performSearch(reset: true) }
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showPremium) {
            NavigationStack { PremiumView() }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Search")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                Text("Find students worldwide")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20))
                .foregroundStyle(Color(hex: "C9A0DC"))
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.08))
                .clipShape(Circle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    // MARK: - Search Bar

    private var searchBarSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.4))

            TextField("Search by name or university...", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .autocorrectionDisabled()
                .focused($isSearchFocused)
                .onSubmit {
                    showAutoComplete = false
                    isSearchFocused = false
                }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    debouncedSearch = ""
                    students = []
                    offset = 0
                    showAutoComplete = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .padding(12)
        .background(Color(hex: "2D3047").opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    // MARK: - Filter Chips

    private var filterChipsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Filter button
                Button { showFilters = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 12))
                        Text("Filters")
                            .font(.system(size: 13, weight: .medium))
                        if filters.hasActive {
                            Circle()
                                .fill(Color(hex: "FF5864"))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .foregroundStyle(filters.hasActive ? .white : .white.opacity(0.6))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(filters.hasActive ? Color(hex: "6C5CE7") : Color(hex: "2D3047"))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.08), lineWidth: 1))
                }

                // Active filter pills
                if !filters.university.isEmpty {
                    activeFilterChip("🎓 \(filters.university)") { filters.university = ""; Task { await performSearch(reset: true) } }
                }
                if !filters.city.isEmpty {
                    activeFilterChip("📍 \(filters.city)") { filters.city = ""; Task { await performSearch(reset: true) } }
                }
                if !filters.country.isEmpty {
                    activeFilterChip("🌍 \(filters.country)") { filters.country = ""; Task { await performSearch(reset: true) } }
                }
                if !filters.gender.isEmpty {
                    activeFilterChip(filters.gender.capitalized) { filters.gender = ""; Task { await performSearch(reset: true) } }
                }
                if filters.minAge != 18 || filters.maxAge != 30 {
                    activeFilterChip("\(filters.minAge)-\(filters.maxAge)y") {
                        filters.minAge = 18; filters.maxAge = 30
                        Task { await performSearch(reset: true) }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 12)
    }

    private func activeFilterChip(_ label: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
            Button { onRemove() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(hex: "6C5CE7").opacity(0.7))
        .clipShape(Capsule())
    }

    // MARK: - Suggestions

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            if let sug = suggestions {
                // Trending Universities
                if let unis = sug.trendingUniversities, !unis.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("Trending Universities", icon: "graduationcap.fill")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(unis) { uni in
                                    Button {
                                        filters.university = uni.name
                                        Task { await performSearch(reset: true) }
                                    } label: {
                                        VStack(spacing: 6) {
                                            Image(systemName: "building.columns.fill")
                                                .font(.system(size: 20))
                                                .foregroundStyle(Color(hex: "C9A0DC"))
                                            Text(uni.name)
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(.white)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.center)
                                            if let count = uni.studentCount {
                                                Text("\(count)")
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(.white.opacity(0.4))
                                            }
                                        }
                                        .frame(width: 90, height: 90)
                                        .background(Color(hex: "2D3047").opacity(0.6))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(.white.opacity(0.06), lineWidth: 1)
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }

                // Top Cities
                if let cities = sug.topCities, !cities.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("Top Cities", icon: "mappin.circle.fill")
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(cities) { city in
                                Button {
                                    filters.city = city.name
                                    Task { await performSearch(reset: true) }
                                } label: {
                                    HStack {
                                        Text(city.name)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(.white)
                                        Spacer()
                                        if let count = city.studentCount {
                                            Text("\(count)")
                                                .font(.system(size: 12))
                                                .foregroundStyle(Color(hex: "C9A0DC"))
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(Color(hex: "2D3047").opacity(0.6))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(.white.opacity(0.06), lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                // Countries
                if let countries = sug.countries, !countries.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("Countries", icon: "globe")
                        VStack(spacing: 8) {
                            ForEach(countries) { country in
                                Button {
                                    filters.country = country.code
                                    Task { await performSearch(reset: true) }
                                } label: {
                                    HStack(spacing: 12) {
                                        Text(country.flag ?? "🌍")
                                            .font(.system(size: 24))
                                        Text(country.name)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(.white)
                                        Spacer()
                                        if let count = country.studentCount {
                                            Text("\(count.formatted())")
                                                .font(.system(size: 13))
                                                .foregroundStyle(Color(hex: "C9A0DC"))
                                        }
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.white.opacity(0.3))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(Color(hex: "2D3047").opacity(0.6))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(.white.opacity(0.06), lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            } else if isLoading {
                loadingView
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 30)
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: "C9A0DC"))
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Autocomplete Dropdown

    private var autoCompleteDropdown: some View {
        VStack(spacing: 0) {
            // Search people option
            Button {
                showAutoComplete = false
                isSearchFocused = false
                // Name search — debounce will trigger performSearch
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.purpleAccent)
                    Text("Search people: \"\(searchText)\"")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            if !matchingUniversities.isEmpty {
                AppColors.darkDivider.frame(height: 1)

                ForEach(matchingUniversities.prefix(5), id: \.self) { uni in
                    Button {
                        debounceTask?.cancel()
                        universitySearchTask?.cancel()
                        filters.university = uni
                        searchText = ""
                        debouncedSearch = ""
                        apiUniversities = []
                        showAutoComplete = false
                        isSearchFocused = false
                        Task { await performSearch(reset: true) }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "graduationcap.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(AppColors.purpleAccent)
                            Text(uni)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }

                    if uni != matchingUniversities.prefix(5).last {
                        AppColors.darkDivider.frame(height: 1).padding(.leading, 40)
                    }
                }
            }
        }
        .background(AppColors.darkCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
        .padding(.horizontal, 20)
    }

    // MARK: - Grouped Results

    private var groupedResultsSection: some View {
        VStack(spacing: 0) {
            if isLoading && students.isEmpty {
                loadingView
            } else if let error = errorMessage, students.isEmpty {
                errorView(error)
            } else if students.isEmpty {
                emptyView
            } else {
                // Count header
                HStack {
                    Text("\(totalResults) students found")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 8)

                // Grouped by university
                ForEach(groupedStudents, id: \.university) { group in
                    // University header
                    HStack(spacing: 8) {
                        Image(systemName: "graduationcap.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.purpleAccent)
                        Text(group.university)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                        Text("(\(group.students.count))")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                    // Student cards under this university
                    ForEach(Array(group.students.enumerated()), id: \.element.id) { _, student in
                        let studentIndex = students.firstIndex(where: { $0.id == student.id }) ?? 0
                        NavigationLink {
                            MatchProfileDetailView(
                                userId: student.id,
                                matchName: student.name ?? "Student",
                                matchPhoto: student.photos?.first ?? ""
                            )
                        } label: {
                            StudentCard(
                                student: student,
                                isPremium: storeKit.isPremium,
                                onLike: { Task { await likeStudent(at: studentIndex) } },
                                onMessage: {
                                    let isMatched = student.interactionStatus == "matched"
                                    if storeKit.isPremium || isMatched {
                                        // TODO: Navigate to chat
                                    } else {
                                        showPremium = true
                                    }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 6)
                    }
                }

                // Load more
                if students.count < totalResults {
                    Button {
                        Task { await performSearch(reset: false) }
                    } label: {
                        if isLoadingMore {
                            ProgressView().tint(AppColors.purpleAccent)
                        } else {
                            Text("Load More")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppColors.purpleAccent)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(hex: "2D3047").opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
            }
        }
        .padding(.bottom, 30)
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Color(hex: "C9A0DC"))
            Text("Searching...")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 32))
                .foregroundStyle(.white.opacity(0.3))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
            Button("Retry") { Task { await performSearch(reset: true) } }
                .font(.subheadline.bold())
                .foregroundStyle(Color(hex: "C9A0DC"))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.3))
            Text("No students found")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))
            Text("Try different filters or search terms")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - API

    private func loadSuggestions() async {
        guard suggestions == nil else { return }
        isLoading = true
        do {
            let result: SearchSuggestions = try await APIService.shared.get(path: "/search/students/suggestions")
            suggestions = result
        } catch {
            suggestions = SearchSuggestions.demo
        }
        isLoading = false
    }

    private func performSearch(reset: Bool) async {
        if reset {
            offset = 0
            isLoading = true
            errorMessage = nil
        } else {
            isLoadingMore = true
        }

        let q = debouncedSearch.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? debouncedSearch
        // Use larger limit when filtering by university to show all profiles
        let limit = !filters.university.isEmpty ? 50 : 20
        var path = "/search/students?limit=\(limit)&offset=\(offset)"
        if !q.isEmpty { path += "&q=\(q)" }
        path += filters.queryString()

        do {
            let result: StudentSearchResponse = try await APIService.shared.get(path: path)
            let fetched = result.students ?? []
            if reset {
                students = fetched.isEmpty ? filterDemos() : fetched
                totalResults = result.total ?? fetched.count
            } else {
                students.append(contentsOf: fetched)
            }
            offset += limit
        } catch {
            if reset && students.isEmpty {
                students = filterDemos()
                totalResults = students.count
            }
        }
        isLoading = false
        isLoadingMore = false
    }

    private func likeStudent(at index: Int) async {
        guard index < students.count else { return }
        let id = students[index].id
        guard !id.hasPrefix("s") || id.count > 2 else {
            // Demo data — just toggle locally
            withAnimation { students[index].interactionStatus = "liked" }
            return
        }

        do {
            let body: [String: Any] = [:]
            let result: StudentLikeResponse = try await APIService.shared.post(path: "/search/students/\(id)/like", body: body)
            withAnimation {
                students[index].interactionStatus = result.isMatch == true ? "matched" : "liked"
            }
        } catch {
            withAnimation { students[index].interactionStatus = "liked" }
        }
    }

    /// Filters demo data to match active filters (university, name query, etc.)
    private func filterDemos() -> [StudentResult] {
        var demos = StudentResult.demos
        if !filters.university.isEmpty {
            demos = demos.filter { ($0.university ?? "").localizedCaseInsensitiveContains(filters.university) }
        }
        if !filters.city.isEmpty {
            demos = demos.filter { ($0.city ?? "").localizedCaseInsensitiveContains(filters.city) }
        }
        let q = debouncedSearch.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            demos = demos.filter {
                ($0.name ?? "").lowercased().contains(q) ||
                ($0.university ?? "").lowercased().contains(q)
            }
        }
        return demos.isEmpty ? StudentResult.demos : demos
    }

    private func searchUniversitiesForAutocomplete(query: String) async {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        do {
            let response: UniversitySearchResponse = try await APIService.shared.get(
                path: "/universities/search?q=\(encoded)&limit=8"
            )
            apiUniversities = response.universities.map(\.displayName)
        } catch {
            // Fallback: filter local demo data
            let lower = query.lowercased()
            apiUniversities = UniversitySearchResult.demos
                .filter { $0.name.lowercased().contains(lower) || ($0.city?.lowercased().contains(lower) ?? false) }
                .map(\.displayName)
        }
    }
}
