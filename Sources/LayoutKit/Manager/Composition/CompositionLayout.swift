//
//  Layout.swift
//  
//
//  Created by Арсений Токарев on 19.03.2022.
//

import UIKit
import OrderedCollections

//MARK: Layout
extension Composition {
    public final class Layout<Section: Hashable, Item: Hashable> {
        private typealias Cache = Configuration.Cache<Section, Item>
        
        internal weak var manager: Manager<Section, Item>?
        internal var provider: Provider?
        
        private let cache = Cache()
        
        private var frame: CGSize {
            return manager?.view.frame.size ?? .zero
        }
        
        internal init(manager: Manager<Section, Item>? = nil) {
            self.manager = manager
        }
        
        public func header(for section: Section) -> CGFloat {
            switch provider?.header?(section, frame) {
            case .absolute(let height):
                return height
            case .automatic:
                return UITableView.automaticDimension
            default:
                return .zero
            }
        }
        public func footer(for section: Section) -> CGFloat {
            switch provider?.footer?(section, frame) {
            case .absolute(let height):
                return height
            case .automatic:
                return UITableView.automaticDimension
            default:
                return .zero
            }
        }
        public func height(for section: Section) -> CGFloat {
            guard let source = manager?.source, let style = style(for: section) else { return .zero }
            let items = source.items(for: section)
            let key = Cache.Section.Fields.Key(width: frame.width, count: items.count)
            guard let cached = cache.height(for: key, in: section) else {
                switch style {
                case .horizontal(let insets, let spacing, let rows, let size):
                    let fullHeight: CGFloat = {
                        let heights = items.map({ size($0)?.height ?? .zero })
                        let rows = rows.count
                        switch rows {
                        case 1:
                            let inset = insets.top + insets.bottom
                            guard let max = heights.max() else { return inset }
                            return inset + max
                        case 2...:
                            let inset     = insets.top + insets.bottom
                            let partition = heights.partition(into: rows)
                            let columns   = partition.map{ part in part.reduce(into: spacing*CGFloat(rows-1)){ $0 += $1 } }
                            guard let max = columns.max() else { return inset }
                            return inset + max
                        default:
                            return insets.top + insets.bottom
                        }
                    }()
                    cache.store(height: fullHeight, for: key, in: section)
                    return fullHeight
                case .grid(let insets, let mode, let size):
                    /// Currently assuming that size for vertical is identical for all cells
                    guard frame.width > 0, !items.isEmpty, let item = items.first, let size = size(item) else {
                        let zero = Configuration.Automatic.zero
                        cache.store(automatic: zero, for: key, in: section)
                        return .zero
                    }
                    let width  = size.width
                    let height = size.height
                    let fit    = frame.width - (insets.right + insets.left)
                    guard fit > width else {
                        let zero = Configuration.Automatic.zero
                        cache.store(automatic: zero, for: key, in: section)
                        return .zero
                    }
                    let limit = mode.spacing
                    guard width*CGFloat(items.count)+limit*CGFloat(items.count-1) > fit else {
                        let automatic = Configuration.Automatic(height: insets.top+height+insets.bottom, interItem: limit, interLine: .zero, columns: 1)
                        cache.store(automatic: automatic, for: key, in: section)
                        return automatic.height
                    }
                    var columns = 0
                    var adaptedSpacing = limit
                    while columns < items.count {
                        columns += 1
                        let updated = (fit - CGFloat(columns)*width)/max(1, CGFloat(columns-1))
                        if updated >= limit {
                            adaptedSpacing = updated
                        } else {
                            columns -= 1
                            break
                        }
                    }
                    let indent = mode.indent ?? adaptedSpacing
                    let fullHeight: CGFloat = {
                        guard columns > 1 else { return height + insets.top + insets.bottom }
                        let rows = (CGFloat(items.count) / CGFloat(columns)).rounded(.up)
                        let indents = max(0, indent * (rows-1))
                        let full = (height * rows) + indents + insets.top + insets.bottom
                        return full
                    }()
                    let automatic = Configuration.Automatic(height: fullHeight, interItem: adaptedSpacing, interLine: indent, columns: columns)
                    cache.store(automatic: automatic, for: key, in: section)
                    return fullHeight
                case .vertical:
                    return source.items(for: section).reduce(into: CGFloat.zero, {
                        $0 += height(for: $1, in: section)
                    })
                case .custom(let height):
                    return height
                }
            }
            return cached
        }
        public func height(for item: Item, in section: Section) -> CGFloat {
            guard let style = style(for: section) else { return .zero }
            switch style {
            case .horizontal, .grid:
                return size(for: item, in: section).height
            case .vertical(let height):
                guard let row = height(item) else { return .zero }
                switch row {
                case .automatic:
                    let key = Cache.Item.Fields.Key(width: frame.width)
                    guard let cached = cache.height(for: key, with: item, in: section) else { return UITableView.automaticDimension }
                    return cached
                case .absolute(let height):
                    return height
                case .zero:
                    return .zero
                }
            case .custom:
                return .zero
            }
        }
        
        public func style(for section: Section) -> Style? {
            return provider?.style?(section, frame)
        }
        
        public func automatic(for section: Section) -> Configuration.Automatic? {
            guard let source = manager?.source else { return nil }
            let key = Cache.Section.Fields.Key(width: frame.width, count: source.items(for: section).count)
            return cache.automatic(for: key, in: section)
        }
        
        public func insets(for section: Section) -> UIEdgeInsets {
            switch style(for: section) {
            case .horizontal(let insets, _, _, _):
                return insets
            case .grid(let insets, _, _):
                return insets
            default:
                return .zero
            }
        }
        
        public func size(for item: Item, in section: Section) -> CGSize {
            switch style(for: section) {
            case .horizontal(_, _, _, let size):
                return size(item) ?? .zero
            case .grid(_, _, let size):
                return size(item) ?? .zero
            default:
                return CGSize(width: frame.width, height: height(for: item, in: section))
            }
        }
        
        public func spacing(for section: Section) -> CGFloat {
            switch style(for: section) {
            case .horizontal(_, let spacing, _, _):
                return spacing
            case .grid:
                return automatic(for: section)?.interItem ?? .zero
            default:
                return .zero
            }
        }
        
        public func indent(for section: Section) -> CGFloat {
            switch style(for: section) {
            case .horizontal(_, let spacing, _, _):
                return spacing
            case .grid:
                return automatic(for: section)?.interLine ?? .zero
            default:
                return .zero
            }
        }
        
        internal func calculated(height: CGFloat, for item: Item, in section: Section) {
            let key = Cache.Item.Fields.Key(width: frame.width)
            cache.store(height: height, for: key, with: item, in: section)
        }
        internal func reload(item: Item, in section: Section) {
            cache.remove(item: item, in: section)
        }
        internal func remove(items: OrderedSet<Item>, in section: Section) {
            cache.remove(items: items, in: section)
        }
        internal func remove(section: Section) {
            cache.remove(section: section)
        }
        internal func remove(sections: OrderedSet<Section>) {
            cache.remove(sections: sections)
        }
        internal func removeAll() {
            cache.removeAll()
        }
    }
}

extension Composition.Layout {
    public enum Dimension {
        case automatic
        case absolute(CGFloat)
        case zero
    }
    public enum Style {
        case grid      (insets: UIEdgeInsets, mode: Mode, size: (Item) -> CGSize?)
        case custom    (height: CGFloat)
        case vertical  (height: (Item) -> Dimension?)
        case horizontal(insets: UIEdgeInsets, spacing: CGFloat, rows: Rows, size: (Item) -> CGSize?)
        
        public enum Mode {
            case automatic(minSpacing: CGFloat, indent: Dimension)
            
            internal var spacing: CGFloat {
                switch self {
                case .automatic(let spacing, _):
                    return spacing
                }
            }
            
            internal var indent: CGFloat? {
                switch self {
                case .automatic(_, let dimension):
                    switch dimension {
                    case .absolute(let indent):
                        return indent
                    case .zero:
                        return .zero
                    default:
                        return nil
                    }
                }
            }
        }
        
        public enum Rows: Equatable {
            case finite(rows: Int)
            case infinite
            
            public var count: Int {
                switch self {
                case .finite(let rows):
                    return rows
                case .infinite:
                    return 1
                }
            }
        }
    }
    public class Provider {
        public typealias Style  = (Section, CGSize) -> Composition.Layout<Section, Item>.Style?
        public typealias Header = (Section, CGSize) -> Dimension?
        public typealias Footer = (Section, CGSize) -> Dimension?
        
        public var style : Style?
        public var header: Header?
        public var footer: Footer?
        
        public init(style : Style? = nil,
                    header: Header? = nil,
                    footer: Footer? = nil) {
            self.style = style
            self.header = header
            self.footer = footer
        }
    }
}

extension Array {
    internal func partition(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
