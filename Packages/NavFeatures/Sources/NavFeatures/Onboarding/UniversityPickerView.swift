import SwiftUI
import NavCore
import NavNetworking

/// Reusable university picker with autocomplete. Shows matching universities
/// (with campus locations) as the user types. Calls `/universities/search` API
/// with fallback to demo data.
struct UniversityPickerView: View {
    @Binding var selectedUniversity: String
    @Binding var selectedLocation: String
    @Binding var selectedStudy: String
    var countryCode: String = ""

    @State private var searchText = ""
    @State private var results: [UniversitySearchResult] = []
    @State private var isSearching = false
    @State private var showResults = false
    @State private var showStudyPicker = false
    @FocusState private var isSearchFocused: Bool

    private let bg = Color(hex: "0F0F1A")

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // University field
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("UNIVERSITY")

                ZStack(alignment: .top) {
                    VStack(spacing: 0) {
                        // Search input
                        HStack(spacing: 10) {
                            Image(systemName: "graduationcap.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color(hex: "C9A0DC"))

                            TextField("", text: $searchText, prompt: Text("Search your university...").foregroundStyle(.white.opacity(0.2)))
                                .font(.system(size: 17, weight: .medium, design: .rounded))
                                .foregroundStyle(.white)
                                .autocorrectionDisabled()
                                .focused($isSearchFocused)
                                .onSubmit { showResults = false }

                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                    selectedUniversity = ""
                                    selectedLocation = ""
                                    results = []
                                    showResults = false
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                            }
                        }
                        .padding(16)
                        .background(.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(isSearchFocused ? Color(hex: "C9A0DC").opacity(0.4) : .white.opacity(0.1), lineWidth: 1)
                        )
                    }

                    // Dropdown results
                    if showResults && (!results.isEmpty || !searchText.trimmingCharacters(in: .whitespaces).isEmpty) {
                        resultsDropdown
                            .padding(.top, 56)
                            .zIndex(10)
                    }
                }

                // Selected university display
                if !selectedUniversity.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(hex: "4ECDC4"))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedUniversity)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            if !selectedLocation.isEmpty {
                                Text(selectedLocation)
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }

                        Spacer()

                        Button {
                            selectedUniversity = ""
                            selectedLocation = ""
                            searchText = ""
                            isSearchFocused = true
                        } label: {
                            Text("Change")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color(hex: "C9A0DC"))
                        }
                    }
                    .padding(12)
                    .background(Color(hex: "4ECDC4").opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            // Study field
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("FIELD OF STUDY")

                Button {
                    showStudyPicker = true
                } label: {
                    HStack {
                        Image(systemName: "book.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(hex: "C9A0DC"))

                        Text(selectedStudy.isEmpty ? "Select your field of study" : selectedStudy)
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundStyle(selectedStudy.isEmpty ? .white.opacity(0.2) : .white)

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(16)
                    .background(.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                    )
                }
            }
        }
        .onChange(of: isSearchFocused) { _, focused in
            if focused && searchText.trimmingCharacters(in: .whitespaces).isEmpty && selectedUniversity.isEmpty {
                showResults = true
                Task { await loadNearbyUniversities() }
            }
        }
        .onChange(of: searchText) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if isSearchFocused && selectedUniversity.isEmpty {
                    showResults = true
                    Task { await loadNearbyUniversities() }
                } else {
                    results = []
                    showResults = false
                }
                return
            }
            // Don't search if we already selected (text matches selection)
            if trimmed == selectedUniversity || (!selectedLocation.isEmpty && trimmed == "\(selectedUniversity) - \(selectedLocation)") {
                showResults = false
                return
            }
            showResults = true
            Task { await searchUniversities(query: trimmed) }
        }
        .sheet(isPresented: $showStudyPicker) {
            studyPickerSheet
        }
    }

    // MARK: - Results Dropdown

    private var resultsDropdown: some View {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespaces)
        return VStack(spacing: 0) {
            if isSearching {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(Color(hex: "C9A0DC"))
                    Text("Searching...")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else if !results.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(results.prefix(8)) { uni in
                            Button {
                                selectUniversity(uni)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "graduationcap.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color(hex: "C9A0DC"))
                                        .frame(width: 28)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(uni.name)
                                            .font(.system(size: 15, weight: .medium, design: .rounded))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)

                                        HStack(spacing: 4) {
                                            if let city = uni.city, !city.isEmpty {
                                                Image(systemName: "mappin")
                                                    .font(.system(size: 9))
                                                Text(city)
                                                    .font(.system(size: 12, design: .rounded))
                                            }
                                            if let country = uni.country, !country.isEmpty,
                                               let city = uni.city, !city.isEmpty {
                                                Text("·")
                                                    .font(.system(size: 12))
                                            }
                                            if let country = uni.country, !country.isEmpty {
                                                Text(country)
                                                    .font(.system(size: 12, design: .rounded))
                                            }
                                        }
                                        .foregroundStyle(.white.opacity(0.4))
                                    }

                                    Spacer()

                                    if let tier = uni.tier, !tier.isEmpty {
                                        Text(tier)
                                            .font(.system(size: 10, weight: .medium, design: .rounded))
                                            .foregroundStyle(Color(hex: "C9A0DC").opacity(0.8))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color(hex: "C9A0DC").opacity(0.12))
                                            .clipShape(Capsule())
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                            }

                            Color.white.opacity(0.06)
                                .frame(height: 1)
                                .padding(.leading, 54)
                        }
                    }
                }
                .frame(maxHeight: 260)
            } else {
                // No results found
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("No matching universities found")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.horizontal, 14).padding(.vertical, 14)
                Color.white.opacity(0.06).frame(height: 1)
            }

            // "Use custom name" button — only when user typed something specific
            if !trimmedSearch.isEmpty && !isSearching {
                Button {
                    selectedUniversity = trimmedSearch
                    selectedLocation = ""
                    searchText = trimmedSearch
                    showResults = false
                    isSearchFocused = false
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(hex: "C9A0DC"))
                        Text("Use \"\(trimmedSearch)\"")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(hex: "C9A0DC"))
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Color(hex: "C9A0DC").opacity(0.08))
                }
            }
        }
        .background(Color(hex: "2D3047"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
    }

    // MARK: - Study Picker Sheet

    private var studyPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(StudyFields.all, id: \.self) { field in
                    Button {
                        selectedStudy = field
                        showStudyPicker = false
                    } label: {
                        HStack {
                            Text(field)
                                .foregroundStyle(.white)
                            Spacer()
                            if selectedStudy == field {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color(hex: "C9A0DC"))
                            }
                        }
                    }
                    .listRowBackground(Color(hex: "2D3047"))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(hex: "1A1B2E").ignoresSafeArea())
            .navigationTitle("Field of Study")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showStudyPicker = false }
                        .foregroundStyle(Color(hex: "C9A0DC"))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(hex: "1A1B2E"))
    }

    // MARK: - Search

    private func loadNearbyUniversities() async {
        isSearching = true
        do {
            var path = "/universities/search?q=&limit=20"
            if !countryCode.isEmpty {
                let cc = countryCode.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? countryCode
                path += "&country=\(cc)"
            }
            let response: UniversitySearchResponse = try await APIService.shared.get(path: path)
            results = response.universities
        } catch {
            results = UniversitySearchResult.demos
        }
        isSearching = false
    }

    private func searchUniversities(query: String) async {
        isSearching = true
        do {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            var path = "/universities/search?q=\(encoded)&limit=10"
            if !countryCode.isEmpty {
                let cc = countryCode.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? countryCode
                path += "&country=\(cc)"
            }
            let response: UniversitySearchResponse = try await APIService.shared.get(path: path)
            // Only update if search text hasn't changed
            if searchText.trimmingCharacters(in: .whitespaces).lowercased().contains(query.lowercased().prefix(3)) {
                results = response.universities
            }
        } catch {
            // Fallback to demo data filtered locally
            let query = query.lowercased()
            results = UniversitySearchResult.demos.filter {
                $0.name.lowercased().contains(query) ||
                ($0.shortName?.lowercased().contains(query) ?? false) ||
                ($0.city?.lowercased().contains(query) ?? false)
            }
        }
        isSearching = false
    }

    // MARK: - Select

    private func selectUniversity(_ uni: UniversitySearchResult) {
        selectedUniversity = uni.name
        selectedLocation = uni.city ?? ""
        searchText = uni.displayName
        showResults = false
        isSearchFocused = false
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.35))
            .tracking(1.2)
    }
}
