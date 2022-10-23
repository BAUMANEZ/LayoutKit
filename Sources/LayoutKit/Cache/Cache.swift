//
//  Cache.swift
//
//  Created by Арсений Токарев on 23.05.2022.
//

import UIKit
import OrderedCollections

public class Configuration {
    public struct Automatic {
        public let height   : CGFloat
        public let interItem: CGFloat
        public let interLine: CGFloat
        public let columns  : Int
        
        public static let zero = Automatic(height: .zero, interItem: .zero, interLine: .zero, columns: .zero)
    }
}

extension Configuration {
    internal final class Cache<SectionIdentifier: Hashable, ItemIdentifier: Hashable> {
        private var sections: [SectionIdentifier: Section.Fields] = [:]
        private var items   : [SectionIdentifier: [ItemIdentifier: Item.Fields]] = [:]
        private var visible : Set<SectionIdentifier> = []
        private var styles  : [SectionIdentifier: Composition.Manager<SectionIdentifier, ItemIdentifier>.Layout.Style] = [:]
        
        internal func clear() {
            sections.removeAll()
            items.removeAll()
            visible.removeAll()
            styles.removeAll()
        }
        
        
        //MARK: - Section Cache
        internal func height(for key: Section.Fields.Key, in section: SectionIdentifier) -> CGFloat? {
            return sections[section]?.height[key]
        }
        internal func store(height: CGFloat, for key: Section.Fields.Key, in section: SectionIdentifier) {
            let cache = sections[section] ?? Section.Fields()
            cache.height[key] = height
            sections[section] = cache
        }
        internal func interItem(for key: Section.Fields.Key, in section: SectionIdentifier) -> CGFloat? {
            return sections[section]?.interItem[key]
        }
        internal func store(interItem: CGFloat, for key: Section.Fields.Key, in section: SectionIdentifier) {
            let cache = sections[section] ?? Section.Fields()
            cache.interItem[key] = interItem
            sections[section] = cache
        }
        internal func interLine(for key: Section.Fields.Key, in section: SectionIdentifier) -> CGFloat? {
            return sections[section]?.interLine[key]
        }
        internal func store(interLine: CGFloat, for key: Section.Fields.Key, in section: SectionIdentifier) {
            let cache = sections[section] ?? Section.Fields()
            cache.interLine[key] = interLine
            sections[section] = cache
        }
        internal func columns(for key: Section.Fields.Key, in section: SectionIdentifier) -> Int? {
            return sections[section]?.columns[key]
        }
        internal func store(columns: Int, for key: Section.Fields.Key, in section: SectionIdentifier) {
            let cache = sections[section] ?? Section.Fields()
            cache.columns[key] = columns
            sections[section] = cache
        }
        internal func automatic(for key: Section.Fields.Key, in section: SectionIdentifier) -> Automatic? {
            return sections[section]?.automatic[key]
        }
        internal func store(automatic: Automatic, for key: Section.Fields.Key, in section: SectionIdentifier) {
            let cache = sections[section] ?? Section.Fields()
            cache.automatic[key] = automatic
            sections[section] = cache
        }
        internal func header(for key: Section.Fields.Key, in section: SectionIdentifier) -> CGFloat? {
            return sections[section]?.header[key]
        }
        internal func store(header: CGFloat, for key: Section.Fields.Key, in section: SectionIdentifier) {
            let cache = sections[section] ?? Section.Fields()
            cache.header[key] = header
            sections[section] = cache
        }
        internal func footer(for key: Section.Fields.Key, in section: SectionIdentifier) -> CGFloat? {
            return sections[section]?.footer[key]
        }
        internal func store(footer: CGFloat, for key: Section.Fields.Key, in section: SectionIdentifier) {
            let cache = sections[section] ?? Section.Fields()
            cache.footer[key] = footer
            sections[section] = cache
        }
        internal func store(visible section: SectionIdentifier) {
            visible.insert(section)
        }
        internal func remove(visible section: SectionIdentifier) {
            visible.remove(section)
        }
        internal func visible(section: SectionIdentifier) -> Bool {
            return visible.contains(section)
        }
        internal func store(style: Composition.Manager<SectionIdentifier, ItemIdentifier>.Layout.Style, in section: SectionIdentifier) {
            styles[section] = style
        }
        internal func style(for section: SectionIdentifier) -> Composition.Manager<SectionIdentifier, ItemIdentifier>.Layout.Style? {
            return styles[section]
        }
        
        
        //MARK: - Item Cache
        internal func size(for key: Item.Fields.Key, with item: ItemIdentifier, in section: SectionIdentifier) -> CGSize? {
            return items[section]?[item]?.size[key]
        }
        internal func store(size: CGSize, for key: Item.Fields.Key, with item: ItemIdentifier, in section: SectionIdentifier) {
            var _section = items[section] ?? [:]
            let cache   = _section[item] ?? Item.Fields()
            cache.size[key] = size
            _section[item] = cache
            items[section] = _section
        }
        internal func width(for key: Item.Fields.Key, with item: ItemIdentifier, in section: SectionIdentifier) -> CGFloat? {
            return items[section]?[item]?.width[key]
        }
        internal func store(width: CGFloat, for key: Item.Fields.Key, with item: ItemIdentifier, in section: SectionIdentifier) {
            var _section = items[section] ?? [:]
            let cache   = _section[item] ?? Item.Fields()
            cache.width[key] = width
            _section[item] = cache
            items[section] = _section
        }
        internal func height(for key: Item.Fields.Key, with item: ItemIdentifier, in section: SectionIdentifier) -> CGFloat? {
            return items[section]?[item]?.height[key]
        }
        internal func store(height: CGFloat, for key: Item.Fields.Key, with item: ItemIdentifier, in section: SectionIdentifier) {
            var _section = items[section] ?? [:]
            let cache   = _section[item] ?? Item.Fields()
            cache.height[key] = height
            _section[item] = cache
            items[section] = _section
        }
        
        //MARK: - Removal
        internal func remove(item: ItemIdentifier, in section: SectionIdentifier) {
            guard var _section = items[section] else { return }
            _section.removeValue(forKey: item)
            self.items[section] = _section
        }
        internal func remove(items: OrderedSet<ItemIdentifier>, in section: SectionIdentifier) {
            guard var _section = self.items[section] else { return }
            items.forEach{ _section.removeValue(forKey: $0) }
            self.items[section] = _section
        }
        internal func remove(section: SectionIdentifier) {
            sections.removeValue(forKey: section)
            items.removeValue(forKey: section)
            visible.remove(section)
            styles.removeValue(forKey: section)
        }
        internal func remove(sections: OrderedSet<SectionIdentifier>) {
            sections.forEach {
                remove(section: $0)
            }
        }
        internal func removeAll() {
            items.removeAll()
            sections.removeAll()
            visible.removeAll()
            styles.removeAll()
        }
    }
}

extension Configuration.Cache {
    internal final class Section {
        internal final class Fields {
            internal var height   : [Key: CGFloat]   = [:]
            internal var interItem: [Key: CGFloat]   = [:]
            internal var interLine: [Key: CGFloat]   = [:]
            internal var columns  : [Key: Int]       = [:]
            internal var automatic: [Key: Configuration.Automatic] = [:]
            internal var header   : [Key: CGFloat]   = [:]
            internal var footer   : [Key: CGFloat]   = [:]
            
            internal func store(height: CGFloat, for key: Key) {
                self.height[key] = height
            }
            internal func store(interItem: CGFloat, for key: Key) {
                self.interItem[key] = interItem
            }
            internal func store(interLine: CGFloat, for key: Key) {
                self.interLine[key] = interLine
            }
            internal func store(columns: Int, for key: Key) {
                self.columns[key] = columns
            }
            internal func store(automatic: Configuration.Automatic, for key: Key) {
                self.automatic[key] = automatic
            }
            internal func store(header: CGFloat, for key: Key) {
                self.header[key] = header
            }
            internal func store(footer: CGFloat, for key: Key) {
                self.footer[key] = footer
            }
            
            internal struct Key: Hashable {
                internal let width: CGFloat
                internal let count: Int
            }
        }
    }
    internal final class Item {
        internal final class Fields {
            internal var size  : [Key: CGSize] = [:]
            internal var width : [Key: CGFloat] = [:]
            internal var height: [Key: CGFloat] = [:]
            
            internal func store(size: CGSize, for key: Key) {
                self.size[key] = size
            }
            internal func store(width: CGFloat, for key: Key) {
                self.width[key] = width
            }
            internal func store(height: CGFloat, for key: Key) {
                self.height[key] = height
            }
            internal struct Key: Hashable {
                internal let width: CGFloat
            }
        }
    }
}
