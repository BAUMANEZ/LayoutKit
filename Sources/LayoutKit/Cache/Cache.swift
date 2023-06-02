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

    final class Cache<SectionIdentifier: Hashable, ItemIdentifier: Hashable> {

        private var sections: [SectionIdentifier: Section.Fields] = [:]
        private var items   : [SectionIdentifier: [ItemIdentifier: Item.Fields]] = [:]
        private var visible : Set<SectionIdentifier> = []
        private var styles  : [SectionIdentifier: Composition.Manager<SectionIdentifier, ItemIdentifier>.Layout.Style] = [:]
        
        func clear() {
            sections.removeAll()
            items.removeAll()
            visible.removeAll()
            styles.removeAll()
        }
        
        
        //MARK: - Section Cache
        func height(for key: Section.Fields.Key, in section: SectionIdentifier) -> CGFloat? {
            return sections[section]?.height[key]
        }

        func store(height: CGFloat, for key: Section.Fields.Key, in section: SectionIdentifier) {
            let cache = sections[section] ?? Section.Fields()
            cache.height[key] = height
            sections[section] = cache
        }

        func interItem(for key: Section.Fields.Key, in section: SectionIdentifier) -> CGFloat? {
            return sections[section]?.interItem[key]
        }

        func store(interItem: CGFloat, for key: Section.Fields.Key, in section: SectionIdentifier) {
            let cache = sections[section] ?? Section.Fields()
            cache.interItem[key] = interItem
            sections[section] = cache
        }

        func interLine(for key: Section.Fields.Key, in section: SectionIdentifier) -> CGFloat? {
            return sections[section]?.interLine[key]
        }

        func store(interLine: CGFloat, for key: Section.Fields.Key, in section: SectionIdentifier) {
            let cache = sections[section] ?? Section.Fields()
            cache.interLine[key] = interLine
            sections[section] = cache
        }

        func columns(for key: Section.Fields.Key, in section: SectionIdentifier) -> Int? {
            return sections[section]?.columns[key]
        }

        func store(columns: Int, for key: Section.Fields.Key, in section: SectionIdentifier) {
            let cache = sections[section] ?? Section.Fields()
            cache.columns[key] = columns
            sections[section] = cache
        }

        func automatic(for key: Section.Fields.Key, in section: SectionIdentifier) -> Automatic? {
            return sections[section]?.automatic[key]
        }

        func store(automatic: Automatic, for key: Section.Fields.Key, in section: SectionIdentifier) {
            let cache = sections[section] ?? Section.Fields()
            cache.automatic[key] = automatic
            sections[section] = cache
        }

        func header(for key: Section.Fields.Key, in section: SectionIdentifier) -> CGFloat? {
            return sections[section]?.header[key]
        }

        func store(header: CGFloat, for key: Section.Fields.Key, in section: SectionIdentifier) {
            let cache = sections[section] ?? Section.Fields()
            cache.header[key] = header
            sections[section] = cache
        }

        func footer(for key: Section.Fields.Key, in section: SectionIdentifier) -> CGFloat? {
            return sections[section]?.footer[key]
        }

        func store(footer: CGFloat, for key: Section.Fields.Key, in section: SectionIdentifier) {
            let cache = sections[section] ?? Section.Fields()
            cache.footer[key] = footer
            sections[section] = cache
        }

        func store(visible section: SectionIdentifier) {
            visible.insert(section)
        }

        func remove(visible section: SectionIdentifier) {
            visible.remove(section)
        }

        func visible(section: SectionIdentifier) -> Bool {
            return visible.contains(section)
        }

        func store(style: Composition.Manager<SectionIdentifier, ItemIdentifier>.Layout.Style, in section: SectionIdentifier) {
            styles[section] = style
        }

        func style(for section: SectionIdentifier) -> Composition.Manager<SectionIdentifier, ItemIdentifier>.Layout.Style? {
            return styles[section]
        }
        
        
        //MARK: - Item Cache
        func size(for key: Item.Fields.Key, with item: ItemIdentifier, in section: SectionIdentifier) -> CGSize? {
            return items[section]?[item]?.size[key]
        }

        func store(size: CGSize, for key: Item.Fields.Key, with item: ItemIdentifier, in section: SectionIdentifier) {
            var _section = items[section] ?? [:]
            let cache   = _section[item] ?? Item.Fields()
            cache.size[key] = size
            _section[item] = cache
            items[section] = _section
        }

        func width(for key: Item.Fields.Key, with item: ItemIdentifier, in section: SectionIdentifier) -> CGFloat? {
            return items[section]?[item]?.width[key]
        }

        func store(width: CGFloat, for key: Item.Fields.Key, with item: ItemIdentifier, in section: SectionIdentifier) {
            var _section = items[section] ?? [:]
            let cache   = _section[item] ?? Item.Fields()
            cache.width[key] = width
            _section[item] = cache
            items[section] = _section
        }

        func height(for key: Item.Fields.Key, with item: ItemIdentifier, in section: SectionIdentifier) -> CGFloat? {
            return items[section]?[item]?.height[key]
        }

        func store(height: CGFloat, for key: Item.Fields.Key, with item: ItemIdentifier, in section: SectionIdentifier) {
            var _section = items[section] ?? [:]
            let cache   = _section[item] ?? Item.Fields()
            cache.height[key] = height
            _section[item] = cache
            items[section] = _section
        }
        
        //MARK: - Removal
        func remove(item: ItemIdentifier, in section: SectionIdentifier) {
            guard var _section = items[section] else { return }
            _section.removeValue(forKey: item)
            self.items[section] = _section
        }

        func remove(items: OrderedSet<ItemIdentifier>, in section: SectionIdentifier) {
            guard var _section = self.items[section] else { return }
            items.forEach{ _section.removeValue(forKey: $0) }
            self.items[section] = _section
        }

        func remove(section: SectionIdentifier) {
            sections.removeValue(forKey: section)
            items.removeValue(forKey: section)
            visible.remove(section)
            styles.removeValue(forKey: section)
        }

        func remove(sections: OrderedSet<SectionIdentifier>) {
            sections.forEach {
                remove(section: $0)
            }
        }

        func removeAll() {
            items.removeAll()
            sections.removeAll()
            visible.removeAll()
            styles.removeAll()
        }
    }
}

extension Configuration.Cache {

    final class Section {

        final class Fields {
            var height   : [Key: CGFloat]   = [:]
            var interItem: [Key: CGFloat]   = [:]
            var interLine: [Key: CGFloat]   = [:]
            var columns  : [Key: Int]       = [:]
            var automatic: [Key: Configuration.Automatic] = [:]
            var header   : [Key: CGFloat]   = [:]
            var footer   : [Key: CGFloat]   = [:]
            
            func store(height: CGFloat, for key: Key) {
                self.height[key] = height
            }

            func store(interItem: CGFloat, for key: Key) {
                self.interItem[key] = interItem
            }

            func store(interLine: CGFloat, for key: Key) {
                self.interLine[key] = interLine
            }

            func store(columns: Int, for key: Key) {
                self.columns[key] = columns
            }

            func store(automatic: Configuration.Automatic, for key: Key) {
                self.automatic[key] = automatic
            }

            func store(header: CGFloat, for key: Key) {
                self.header[key] = header
            }

            func store(footer: CGFloat, for key: Key) {
                self.footer[key] = footer
            }
            
            struct Key: Hashable {
                let width: CGFloat
                let count: Int
            }
        }
    }

    final class Item {

        final class Fields {

            var size  : [Key: CGSize] = [:]
            var width : [Key: CGFloat] = [:]
            var height: [Key: CGFloat] = [:]
            
            func store(size: CGSize, for key: Key) {
                self.size[key] = size
            }
            func store(width: CGFloat, for key: Key) {
                self.width[key] = width
            }
            func store(height: CGFloat, for key: Key) {
                self.height[key] = height
            }
            struct Key: Hashable {
                let width: CGFloat
            }
        }
    }
}
