//
//  Source.swift
//  
//
//  Created by Арсений Токарев on 19.03.2022.
//

import UIKit
import OrderedCollections

//MARK: - Source
extension Composition {
    public final class Source<Section: Hashable, Item: Hashable> {
        public fileprivate(set) var pages   : [Section: Int] = [:]
        public fileprivate(set) var offsets : [Section: CGPoint] = [:]
        public fileprivate(set) var selected: Set<Item> = []
        public fileprivate(set) var wrappers: [Section: String] = [:]
                
        public lazy var snapshot = Snapshot(source: self)
        internal var provider: Provider?
        
        internal weak var behaviour: Behaviour<Section, Item>?
        internal weak var manager  : Manager<Section, Item>?
        internal weak var layout   : Layout<Section, Item>?
        
        internal init(manager: Manager<Section, Item>? = nil, layout: Layout<Section, Item>? = nil, behaviour: Behaviour<Section, Item>? = nil) {
            self.manager = manager
            self.layout = layout
        }
        
        //MARK: Data Source
        internal func set(item: Item, selected: Bool) {
            if selected {
                self.selected.insert(item)
            } else {
                self.selected.remove(item)
            }
        }
        internal func selectAll() {
            sections.forEach { section in
                items(for: section).forEach { item in
                    self.selected.insert(item)
                }
            }
        }
        internal func deselectAll() {
            self.selected.removeAll()
        }
        internal func selected(indexPath: IndexPath) -> Bool {
            guard let item = item(for: indexPath) else { return false }
            return selected(item: item)
        }
        public func selected(item: Item) -> Bool {
            return selected.contains(item)
        }
        
        internal func save(offset: CGPoint, in section: Section) {
            offsets[section] = offset
        }
        public func offset(in section: Section) -> CGPoint? {
            return offsets[section]
        }
        
        internal func save(page: Int, in section: Section) {
            pages[section] = page
        }
        public func page(in section: Section) -> Int? {
            return pages[section]
        }
        
        internal func identifier(for wrapper: Section) -> String? {
            return self.wrappers[wrapper]
        }
        internal func set(identifier: String, for wrapper: Section) {
            self.wrappers[wrapper] = identifier
        }
        
        //MARK: Get section or item
        public var sections: OrderedSet<Section> {
            return snapshot.sections
        }
        public func section(for index: Int) -> Section? {
            let sections = sections
            return sections.indices.contains(index) ? sections[index] : nil
        }
        public func section(for item: Item) -> Section? {
            return snapshot.items.first(where: { $0.value.contains(item) })?.key
        }
        public func index(for section: Section) -> Int? {
            return sections.firstIndex(of: section)
        }
        public func items(for section: Section) -> OrderedSet<Item> {
            return snapshot.items[section] ?? []
        }
        public func item(for indexPath: IndexPath) -> Item? {
            guard let section = section(for: indexPath.section),
                  let rows = snapshot.items[section], rows.indices.contains(indexPath.item)
            else { return nil }
            return rows[indexPath.item]
        }
        public func indexPath(for item: Item) -> IndexPath? {
            guard let pair = snapshot.items.first(where: { $1.contains(item) }),
                  let _section = snapshot.sections.firstIndex(of: pair.key),
                  let _item = pair.value.firstIndex(of: item)
            else { return nil }
            return IndexPath(item: _item, section: _section)
        }
        
        public func contains(section: Section) -> Bool {
            sections.contains(section)
        }
        public func contains(item: Item) -> Bool {
            return snapshot.items.first(where: { $1.contains(item) }) != nil
        }
        
        public func cell(for indexPath: IndexPath) -> Compositional? {
            guard let section = self.section(for: indexPath.section),
                  let item = self.item(for: indexPath),
                  let cell = provider?.cell?(indexPath, section, item)
            else { return  nil }
            return cell
        }
        public func header(for section: Int) -> Boundary? {
            let index = section
            guard let section = self.section(for: index) else { return nil }
            return provider?.header?(index, section)
        }
        public func footer(for section: Int) -> Boundary? {
            let index = section
            guard let section = self.section(for: index) else { return nil }
            return provider?.footer?(index, section)
        }
    }
}

extension Composition.Source {
    public class Provider {
        public typealias Cell   = (IndexPath, Section, Item) -> Compositional?
        public typealias Header = (Int, Section) -> Boundary?
        public typealias Footer = (Int, Section) -> Boundary?
        
        public var cell  : Cell?
        public var header: Header?
        public var footer: Footer?
        
        public init(cell: Cell? = nil, header: Header? = nil, footer: Footer? = nil) {
            self.cell = cell
            self.header = header
            self.footer = footer
        }
    }
}

extension Composition.Source {
    public final class Snapshot {
        private typealias Pair = (index: Int, section: Section)
        
        fileprivate weak var source: Composition.Source<Section, Item>?
        fileprivate var sections: OrderedSet<Section> = []
        fileprivate var items: [Section: OrderedSet<Item>] = [:]
        
        fileprivate init(source: Composition.Source<Section, Item>) {
            self.source = source
        }
        
        public func batch(updates: [Update], animation: UITableView.RowAnimation?) {
            guard let list = source?.manager?.view else { return }
            for update in updates {
                var dSections: IndexSet?
                var iSections: IndexSet?
                var rSections: IndexSet?
                var dItems: Set<IndexPath> = []
                var iItems: Set<IndexPath> = []
                switch update {
                case .setSections(let sections, let items):
                    self.set(sections: sections, items: items) { delete, insert in
                        dSections = delete
                        iSections = insert
                    }
                case .addSections(let sections, let items):
                    self.add(sections: sections, items: items) { insert in
                        iSections = insert
                    }
                case .deleteSections(let sections):
                    self.delete(sections: sections) { delete in
                        dSections = delete
                    }
                case .reloadSections(let sections):
                    self.reload(sections: sections) { reload in
                        rSections = reload
                    }
                case .setItems(let items, let section):
                    self.set(items: items, to: section) { delete, insert in
                        dItems = delete
                    }
                case .addItems(let items, let section):
                    self.add(items: items, to: section) { insert in
                        iItems = insert
                    }
                case .refresh:
                    self.refresh()
                    list.beginUpdates()
                    list.endUpdates()
                }
                if let dSections = dSections, !dSections.isEmpty {
                    guard let animation = animation else { list.reloadData(); continue }
                    list.beginUpdates()
                    list.deleteSections(dSections, with: animation)
                    list.endUpdates()
                }
                if let iSections = iSections, !iSections.isEmpty {
                    guard let animation = animation else { list.reloadData(); continue }
                    list.beginUpdates()
                    list.insertSections(iSections, with: animation)
                    list.endUpdates()
                }
                if let rSections = rSections, !rSections.isEmpty {
                    guard let animation = animation else { list.reloadData(); continue }
                    list.beginUpdates()
                    list.reloadSections(rSections, with: animation)
                    list.endUpdates()
                }
                if !dItems.isEmpty {
                    guard let animation = animation else { list.reloadData(); continue }
                    list.beginUpdates()
                    list.deleteRows(at: Array(dItems), with: animation)
                    list.endUpdates()
                }
                if !iItems.isEmpty {
                    guard let animation = animation else { list.reloadData(); continue }
                    list.beginUpdates()
                    list.insertRows(at: Array(iItems), with: animation)
                    list.endUpdates()
                }
            }
        }

        private func set(sections: OrderedSet<Section>, items: ((Section) -> OrderedSet<Item>?)?, completion: (IndexSet, IndexSet) -> Void) {
            source?.layout?.removeAll()
            source?.pages.removeAll()
            source?.offsets.removeAll()
            source?.selected.removeAll()
            source?.wrappers.removeAll()
            let delete = IndexSet(self.sections.indices)
            let insert = IndexSet(sections.indices)
            let grids = self.sections.enumerated().compactMap { index, section in
                return ((source?.manager?.view.cellForRow(at: IndexPath(item: 0, section: index)) as? Cell.Listed)?.wrapped as? Cell.Wrapper<Section, Item>)?.grid?.view
            }
            self.sections = sections
            self.items.removeAll()
            sections.enumerated().forEach { index, updated in
                guard let items = items?(updated), items.count > 0 else { return }
                self.items[updated] = items
            }
            grids.forEach { grid in
                grid.performBatchUpdates{ grid.deleteItems(at: (0..<grid.numberOfItems(inSection: 0)).map{IndexPath(item: $0, section: 0)} )}
            }
            completion(delete, insert)
        }
        
        private func add(sections: OrderedSet<Section>, items: ((Section) -> OrderedSet<Item>?)?, completion: (IndexSet) -> Void) {
            guard sections.count > 0 else { completion([]); return }
            let insert = IndexSet(sections.indices.map{ $0 + self.sections.count })
            self.sections.append(contentsOf: sections)
            sections.enumerated().forEach { index, new in
                guard let items = items?(new), items.count > 0 else { return }
                self.items[new] = items
            }
            completion(insert)
        }
        
        private func delete(sections: OrderedSet<Section>, completion: (IndexSet) -> Void) {
            sections.forEach {
                source?.layout?.remove(sections: sections)
                source?.pages.removeValue(forKey: $0)
                source?.offsets.removeValue(forKey: $0)
                items[$0]?.forEach{ item in source?.selected.remove(item)}
                source?.wrappers.removeValue(forKey: $0)
            }
            let pairs = sections.reduce(into: [Pair]()) {
                guard let index = self.sections.firstIndex(of: $1) else { return () }
                $0.append(Pair(index: index, section: $1))
            }
            let delete = IndexSet(Set(pairs.map{$0.index}))
            let grids = pairs.compactMap { index, section in
                return ((source?.manager?.view.cellForRow(at: IndexPath(item: 0, section: index)) as? Cell.Listed)?.wrapped as? Cell.Wrapper<Section, Item>)?.grid?.view
            }
            self.sections = self.sections.subtracting(sections)
            sections.forEach{ self.items.removeValue(forKey: $0) }
            grids.forEach { grid in
                grid.performBatchUpdates{ grid.deleteItems(at: (0..<grid.numberOfItems(inSection: 0)).map{IndexPath(item: $0, section: 0)} )}
            }
            completion(delete)
        }
        
        private func reload(sections: OrderedSet<Section>, completion: (IndexSet) -> Void) {
            source?.layout?.remove(sections: sections)
            let _sections = Set(sections.compactMap{ self.sections.firstIndex(of: $0) })
            completion(IndexSet(_sections))
        }
        
        private func set(items: OrderedSet<Item>, to section: Section, completion: (Set<IndexPath>, Set<IndexPath>) -> Void) {
            guard let _section = self.sections.firstIndex(of: section),
                  let source = source,
                  let layout = source.layout,
                  let style = layout.style(for: section)
            else { completion([], []); return }
            let update = self.items[section] ?? []
            let delete = update.indices
            let insert = items.indices
            self.items[section] = items
            switch style {
            case .vertical:
                completion(
                    Set(delete.map{ IndexPath(item: $0, section: _section) }),
                    Set(insert.map{ IndexPath(item: $0, section: _section) })
                )
            default:
                if let grid = ((source.manager?.view.cellForRow(at: IndexPath(item: 0, section: _section)) as? Cell.Listed)?.wrapped as? Cell.Wrapper<Section, Item>)?.grid?.view {
                    grid.performBatchUpdates {
                        grid.deleteItems(at: delete.map{ IndexPath(item: $0, section: 0) })
                        grid.insertItems(at: insert.map{ IndexPath(item: $0, section: 0) })
                    }
                }
                completion([], [])
            }
        }
        private func add(items: OrderedSet<Item>, to section: Section, completion: (Set<IndexPath>) -> Void) {
            guard items.count > 0, let _section = self.sections.firstIndex(of: section) else { completion([]); return }
            var update = self.items[section] ?? []
            let _items = update.count
            update.append(contentsOf: items)
            self.items[section] = update
            switch source?.layout?.style(for: section) {
            case .vertical:
                completion(Set(items.indices.map{ IndexPath(item: _items+$0, section: _section) }))
            default:
                if let grid = ((source?.manager?.view.cellForRow(at: IndexPath(item: 0, section: _section)) as? Cell.Listed)?.wrapped as? Cell.Wrapper<Section, Item>)?.grid?.view {
                    grid.performBatchUpdates {
                        grid.insertItems(at: items.indices.map{ IndexPath(item: _items+$0, section: 0) })
                    }
                }
                completion([])
            }
        }
        
        private func refresh() {
            source?.layout?.removeAll()
        }
        
        public enum Update {
            case setSections(OrderedSet<Section>, items: ((Section) -> OrderedSet<Item>?)?)
            case addSections(OrderedSet<Section>, items: ((Section) -> OrderedSet<Item>?)?)
            case deleteSections(OrderedSet<Section>)
            case reloadSections(OrderedSet<Section>)
            
            case setItems(OrderedSet<Item>, to: Section)
            case addItems(OrderedSet<Item>, to: Section)
            
            case refresh
        }
    }
}