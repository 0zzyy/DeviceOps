import Foundation

public struct PaginationState<T: Equatable & Codable>: Equatable {
    public private(set) var items: [T]
    public private(set) var page: Int
    public private(set) var totalPages: Int

    public init() {
        self.items = []
        self.page = 0
        self.totalPages = 1
    }

    public mutating func appendPage(_ page: Page<T>) {
        self.page = page.page
        self.totalPages = page.totalPages
        if page.page == 1 {
            items = page.items
        } else {
            items.append(contentsOf: page.items)
        }
    }

    public var canLoadMore: Bool {
        page < totalPages
    }
}
