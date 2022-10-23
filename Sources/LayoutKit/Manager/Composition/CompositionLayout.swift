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
        
        private let cache = Cache()
        internal weak var manager: Manager<Section, Item>?
        internal var provider: Provider?
        
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
                let key = Cache.Section.Fields.Key(width: frame.width, count: manager?.source.items(for: section).count ?? 0)
                guard let cached = cache.header(for: key, in: section) else {
                    return UITableView.automaticDimension
                }
                return cached
            default:
                return .zero
            }
        }
        public func footer(for section: Section) -> CGFloat {
            switch provider?.footer?(section, frame) {
            case .absolute(let height):
                return height
            case .automatic:
                let key = Cache.Section.Fields.Key(width: frame.width, count: manager?.source.items(for: section).count ?? 0)
                guard let cached = cache.footer(for: key, in: section) else {
                    return UITableView.automaticDimension
                }
                return cached
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
                    reload(grid: section)
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
                    guard fit >= width else {
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
                    reload(grid: section)
                    return fullHeight
                case .vertical(_, let separator):
                    return source.items(for: section).reduce(into: CGFloat.zero, {
                        $0 += height(for: $1, in: section)+(separator?.height ?? .zero)
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
            case .vertical(let height, _):
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
            guard let cached = cache.style(for: section) else {
                guard let style = provider?.style?(section, frame) else { return nil }
                cache.store(style: style, in: section)
                return style
            }
            return cached
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
        
        internal func visible(section: Section) -> Bool {
            return cache.visible(section: section)
        }
        internal func set(section: Section, visible: Bool) {
            guard visible else {
                cache.remove(visible: section)
                return
            }
            cache.store(visible: section)
        }
        internal func calculated(height: CGFloat, for item: Item, in section: Section) {
            let key = Cache.Item.Fields.Key(width: frame.width)
            if cache.height(for: key, with: item, in: section) == nil {
                cache.store(height: height, for: key, with: item, in: section)                
            }
        }
        internal func calculated(header: CGFloat, in section: Section) {
            let key = Cache.Section.Fields.Key(width: frame.width, count: manager?.source.items(for: section).count ?? 0)
            if cache.header(for: key, in: section) == nil {
                cache.store(header: header, for: key, in: section)
            }
        }
        internal func calculated(footer: CGFloat, in section: Section) {
            let key = Cache.Section.Fields.Key(width: frame.width, count: manager?.source.items(for: section).count ?? 0)
            if cache.footer(for: key, in: section) == nil {
                cache.store(footer: footer, for: key, in: section)
            }
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
        
        private func reload(grid section: Section) {
            DispatchQueue.main.async { [weak self] in
                guard let index = self?.manager?.source.index(for: section) else { return }
                ((self?.manager?.view.cellForRow(at: IndexPath(item: 0, section: index)) as? Cell.Listed)?.wrapped as? Cell.Wrapper<Section, Item>)?.grid?.view.reloadData()
            }
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
        case vertical  (height: (Item) -> Dimension?, separator: Separator?)
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
            case finite(rows: Int, scrolling: Scrolling)
            case infinite(scrolling: Scrolling)
            
            public var count: Int {
                switch self {
                case .finite(let rows, _):
                    return rows
                case .infinite:
                    return 1
                }
            }
            public enum Scrolling {
                case centerted
                case automatic
            }
        }
        public enum Separator {
            case spacer(CGFloat, includingLast: Bool = false)
            case line(color: UIColor, thickness: CGFloat, insets: UIEdgeInsets, includingLast: Bool = false)
            case custom(UIView, thickness: CGFloat, insets: UIEdgeInsets, includingLast: Bool = false)
            
            public var includingLast: Bool {
                switch self {
                case .spacer(_, let flag), .line(_, _, _, let flag), .custom(_, _, _, let flag):
                    return flag
                }
            }
            
            public var height: CGFloat {
                switch self {
                case .spacer(let space, _):
                    return space
                case .line(_, let thickness, let insets, _):
                    return thickness+insets.top+insets.bottom
                case .custom(_, let thickness, let insets, _):
                    return thickness+insets.top+insets.bottom
                }
            }
            
            public var view: UIView {
                let view: UIView
                let height: CGFloat
                let insets: UIEdgeInsets
                switch self {
                case .spacer(let space, _):
                    view = UIView()
                    height = space
                    insets = .zero
                case .line(let color, let thickness, let _insets, _):
                    view = UIView(); view.backgroundColor = color
                    height = thickness
                    insets = _insets
                case .custom(let _view, let thickness, let _insets, _):
                    view = _view
                    height = thickness
                    insets = _insets
                }
                let container = UIView()
                container.translatesAutoresizingMaskIntoConstraints = false
                view.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(view)
                view.topAnchor.constraint(equalTo: container.topAnchor, constant: insets.top).isActive = true
                view.leftAnchor.constraint(equalTo: container.leftAnchor, constant: insets.left).isActive = true
                view.rightAnchor.constraint(equalTo: container.rightAnchor, constant: -insets.right).isActive = true
                view.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -insets.bottom).isActive = true
                view.heightAnchor.constraint(equalToConstant: height).isActive = true
                return container
            }
        }
    }
    public class Provider {
        public typealias Style  = (_ section: Section, _ frame: CGSize) -> Composition.Layout<Section, Item>.Style?
        public typealias Header = (_ section: Section, _ frame: CGSize) -> Dimension?
        public typealias Footer = (_ section: Section, _ frame: CGSize) -> Dimension?
        
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
