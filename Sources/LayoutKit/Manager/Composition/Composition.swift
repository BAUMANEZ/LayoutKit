//
//  Composition.swift
//  
//
//  Created by Арсений Токарев on 19.03.2022.
//

import UIKit
import OrderedCollections

public protocol CompositionDelegate: AnyObject {
    associatedtype Section: Hashable
    associatedtype Item: Hashable
    
    func will(display cell: Cell, with item: Item, in section: Section, for indexPath: IndexPath)
    func end(display cell: Cell, with item: Item, in section: Section, for indexPath: IndexPath)
    func selected(cell: Cell, with item: Item, in section: Section, for indexPath: IndexPath)
    func deselected(cell: Cell, with item: Item, in section: Section, for indexPath: IndexPath)
    func highlightable(cell: Cell, with item: Item, in section: Section, for indexPath: IndexPath) -> Bool
    func highlighted(cell: Cell, with item: Item, in section: Section, for indexPath: IndexPath)
    func unhighlighted(cell: Cell, with item: Item, in section: Section, for indexPath: IndexPath)
    func will(edit cell: Cell, with item: Item, in section: Section, for indexPath: IndexPath)
    func did(edit cell: Cell, with item: Item, in section: Section, for indexPath: IndexPath)
    func selectable(cell: Cell, with item: Item, in section: Section, for indexPath: IndexPath) -> Bool
    func deselectable(cell: Cell, with item: Item, in section: Section, for indexPath: IndexPath) -> Bool
    func should(update focus: FocusUpdateContext) -> Bool
    func update(focus context: FocusUpdateContext, using coordinator: UIFocusAnimationCoordinator)
    func focused(cell: Cell, with item: Item, in section: Section, for indexPath: IndexPath, with context: FocusUpdateContext, using coordinator: UIFocusAnimationCoordinator)
    func focusable(cell: Cell, with item: Item, in section: Section, for indexPath: IndexPath) -> Bool
 
    func will(display header: Boundary, above section: Section, at index: Int)
    func did(display header: Boundary, above section: Section, at index: Int)
    func will(display footer: Boundary, below section: Section, at index: Int)
    func did(display footer: Boundary, below section: Section, at index: Int)
    func selectable(header: Boundary, in section: Section, at index: Int) -> Bool
    func selectable(footer: Boundary, in section: Section, at index: Int) -> Bool
    func selected(header: Boundary, in section: Section, at index: Int)
    func selected(footer: Boundary, in section: Section, at index: Int)
    func highlightable(header: Boundary, in section: Section, at index: Int) -> Bool
    func highlightable(footer: Boundary, in section: Section, at index: Int) -> Bool
    func highlighted(header: Boundary, in section: Section, at index: Int)
    func highlighted(footer: Boundary, in section: Section, at index: Int)
    func unhighlighted(header: Boundary, in section: Section, at index: Int)
    func unhighlighted(footer: Boundary, in section: Section, at index: Int)
    func focusable(header: Boundary, in section: Section, at index: Int) -> Bool
    func focusable(footer: Boundary, in section: Section, at index: Int) -> Bool
    func focused(header: Boundary, in section: Section, at index: Int)
    func focused(footer: Boundary, in section: Section, at index: Int)
    
    func scrolled()
}

extension Composition {
    open class Manager<Section: Hashable, Item: Hashable>: NSObject, UITableViewDelegate, UITableViewDataSource, CompositionDelegate, BoundaryDelegate {
        public typealias Layout    = Composition.Layout<Section, Item>
        public typealias Source    = Composition.Source<Section, Item>
        public typealias Behaviour = Composition.Behaviour<Section, Item>
        
        internal let view: UITableView
        
        public let source   : Source
        public let layout   : Layout
        public let behaviour: Behaviour
        
        #if os(tvOS)
        public var lastFocusedIndexPath: IndexPath?
        #endif
        private var lastDequedCell: Cell.Listed?
        private var lastDequedBoundary: Boundary.Listed?
        
        //MARK: - Interface Settings
        /// - behaviour defines interaction parameters
        /// - insets for list's interior content
        /// - margins for list's exterior container
        open var scrolling: Composition.Scrolling {
            return Scrolling(vBounce: true, vScroll: true, hBounce: false, hScroll: false)
        }
        open var insets: UIEdgeInsets {
            return .zero
        }
        open var margins: UIEdgeInsets {
            return .zero
        }
        
        public final var scroll: UIScrollView {
            return view
        }
        public final var contentOffset: CGPoint {
            return view.contentOffset
        }
        
        //MARK: - Init
        public init(in content: UIView) {
            self.view = UITableView(frame: content.bounds, style: .grouped)
            self.layout = Layout()
            self.behaviour = Behaviour()
            self.source = Source()
            super.init()
            layout.manager = self
            source.manager = self
            behaviour.manager = self
            setup(in: content)
        }
        
        private func setup(in content: UIView) {
            view.register(Cell.self)
            register()
            view.delegate = self
            view.dataSource = self
            
            #if os(iOS)
            view.separatorStyle = .none
            #endif
            view.separatorInset = .zero
            view.clipsToBounds = true
            view.backgroundColor = nil
            view.sectionHeaderHeight = 0
            view.sectionFooterHeight = 0
            view.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: Double.leastNormalMagnitude))
            view.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: Double.leastNonzeroMagnitude))
            view.insetsContentViewsToSafeArea = false
            view.insetsLayoutMarginsFromSafeArea = false
            view.contentInsetAdjustmentBehavior = .never
            view.contentInset = insets
            view.allowsMultipleSelection = true
            
            let behaviour = scrolling
            view.alwaysBounceVertical           = behaviour.vBounce
            view.showsVerticalScrollIndicator   = behaviour.vScroll
            view.alwaysBounceHorizontal         = behaviour.hBounce
            view.showsHorizontalScrollIndicator = behaviour.hScroll
            
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
            
            let margins = margins
            view.topAnchor.constraint(equalTo: content.topAnchor, constant: margins.top).isActive = true
            view.leftAnchor.constraint(equalTo: content.leftAnchor, constant: margins.left).isActive = true
            view.rightAnchor.constraint(equalTo: content.rightAnchor, constant: -margins.right).isActive = true
            view.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -margins.bottom).isActive = true
        }
        
        open func set(sections: OrderedDictionary<Section, OrderedSet<Item>>, animated: Bool) {
            source.snapshot.batch(updates: [.setSections(sections.keys, items: { sections[$0] })], animation: animated ? .fade : nil)
        }
        open func append(sections: OrderedDictionary<Section, OrderedSet<Item>>, animated: Bool) {
            source.snapshot.batch(updates: [.appendSections(sections.keys, items: { sections[$0] })], animation: animated ? .fade : nil)
        }
        open func reloadAll(animated: Bool) {
            source.snapshot.batch(updates: [.reloadSections(source.sections)], animation: animated ? .fade : nil)
        }
        open func deleteAll(animated: Bool) {
            source.snapshot.batch(updates: [.deleteSections(source.sections)], animation: animated ? .fade : nil)
        }

        //MARK: UITableViewDataSource
        public final func numberOfSections(
            in tableView: UITableView
        ) -> Int {
            return source.sections.count
        }
        public final func tableView(
            _ tableView: UITableView,
            numberOfRowsInSection section: Int
        ) -> Int {
            guard let section = source.section(for: section) else { return .zero }
            switch layout.style(for: section) {
            case .vertical:
                return source.items(for: section).count
            default:
                return 1
            }
        }
        
        public final func tableView(
            _ tableView: UITableView,
            cellForRowAt indexPath: IndexPath
        ) -> UITableViewCell {
            guard let section = source.section(for: indexPath.section) else { return UITableViewCell() }
            switch layout.style(for: section) {
            case .vertical(_, let separator):
                guard let cell = source.cell(for: indexPath) as? Cell,
                      let listed = lastDequedCell ?? tableView.dequeue(cell: cell, for: indexPath)
                else { return UITableViewCell()  }
                lastDequedCell = nil
                cell.selected = source.selected(indexPath: indexPath)
                cell.set(selected: cell.selected, animated: false)
                if cell.dequeID != listed.wrapped?.dequeID {
                    listed.wrap(cell: cell)
                }
                if let separator, separator.includingLast || source.separatable(for: indexPath) {
                    listed.insert(separator: separator.view, height: separator.height)
                }
                return listed
            case .custom:
                guard let cell = source.cell(for: indexPath) as? Cell,
                      let listed = tableView.dequeue(cell: cell, for: indexPath)
                else { return UITableViewCell()  }
                cell.selected = source.selected(indexPath: indexPath)
                cell.set(selected: cell.selected, animated: false)
                if cell.dequeID != listed.wrapped?.dequeID {
                    listed.wrap(cell: cell)
                }
                return listed
            default:
                return wrapper(section: section, for: indexPath.section) ?? UITableViewCell()
            }
        }
        public final func tableView(
            _ tableView: UITableView,
            viewForHeaderInSection section: Int
        ) -> UIView? {
            guard let boundary = source.header(for: section),
                  let listed = lastDequedBoundary ?? tableView.dequeue(boundary)
            else { return nil }
            lastDequedBoundary = nil
            listed.delegate = self
            listed.section = section
            if boundary.dequeID != listed.wrapped?.dequeID {
                listed.wrap(boundary: boundary, isHeader: true)
            }
            return listed
        }
        public final func tableView(
            _ tableView: UITableView,
            viewForFooterInSection section: Int
        ) -> UIView? {
            guard let boundary = source.footer(for: section),
                  let listed = tableView.dequeue(boundary)
            else { return nil }
            listed.delegate = self
            listed.section = section
            if boundary.dequeID != listed.wrapped?.dequeID {
                listed.wrap(boundary: boundary, isHeader: false)
            }
            return listed
        }
        
        //MARK: - UITableViewLayout
        public final func tableView(
            _ tableView: UITableView,
            heightForRowAt indexPath: IndexPath
        ) -> CGFloat {
            guard let section = source.section(for: indexPath.section),
                  let style = layout.style(for: section)
            else { return .zero }
            switch style {
            case .grid, .horizontal:
                return layout.height(for: section)
            case .vertical(_, let separator):
                guard let item = source.item(for: indexPath) else { return .zero }
                let height = layout.height(for: item, in: section)
                guard height != UITableView.automaticDimension else { return height }
                let _separator: CGFloat = {
                    guard let separator = separator, separator.includingLast || source.separatable(for: indexPath) else {
                        return .zero
                    }
                    return separator.height
                }()
                return height+(_separator)
            case .custom(let height):
                return height
            }
        }
        public final func tableView(
            _ tableView: UITableView,
            estimatedHeightForRowAt indexPath: IndexPath
        ) -> CGFloat {
            guard let section = source.section(for: indexPath.section),
                  let style = layout.style(for: section)
            else { return .zero }
            switch style {
            case .grid, .horizontal:
                return layout.height(for: section)
            case .vertical(_, let separator):
                guard let item = source.item(for: indexPath) else { return .zero }
                let height = layout.height(for: item, in: section)
                guard height != UITableView.automaticDimension else { return height }
                let _separator: CGFloat = {
                    guard let separator = separator, separator.includingLast || source.separatable(for: indexPath) else {
                        return .zero
                    }
                    return separator.height
                }()
                return height+(_separator)
            case .custom(let height):
                return height
            }
        }
        public final func tableView(
            _ tableView: UITableView,
            heightForHeaderInSection section: Int
        ) -> CGFloat {
            guard let section = source.section(for: section) else { return .zero }
            return layout.header(for: section)
        }
        public final func tableView(
            _ tableView: UITableView,
            estimatedHeightForHeaderInSection section: Int
        ) -> CGFloat {
            guard let section = source.section(for: section) else { return .zero }
            return layout.header(for: section)
        }
        public final func tableView(
            _ tableView: UITableView,
            heightForFooterInSection section: Int
        ) -> CGFloat {
            guard let section = source.section(for: section) else { return .zero }
            return layout.footer(for: section)
        }
        public final func tableView(
            _ tableView: UITableView,
            estimatedHeightForFooterInSection section: Int
        ) -> CGFloat {
            guard let section = source.section(for: section) else { return .zero }
            return layout.footer(for: section)
        }
        
        //MARK: - UITableViewDelegate
        public final func tableView(
            _ tableView: UITableView,
            willDisplay cell: UITableViewCell,
            forRowAt indexPath: IndexPath
        ) {
            guard let section = source.section(for: indexPath.section),
                  let item = source.item(for: indexPath),
                  let cell = (cell as? Cell.Listed)?.wrapped
            else { return }
            (cell as? Cell.Wrapper<Section, Item>)?.grid?.restore()
            will(display: cell, with: item, in: section, for: indexPath)
        }
        public final func tableView(
            _ tableView: UITableView,
            didEndDisplaying cell: UITableViewCell,
            forRowAt indexPath: IndexPath
        ) {
            guard let section = source.section(for: indexPath.section),
                  let item = source.item(for: indexPath),
                  let cell = (cell as? Cell.Listed)?.wrapped
            else { return }
            if !source.snapshot.updating {
                layout.calculated(height: cell.bounds.height, for: item, in: section)
            }
            end(display: cell, with: item, in: section, for: indexPath)
        }
        public final func tableView(
            _ tableView: UITableView,
            willSelectRowAt indexPath: IndexPath
        ) -> IndexPath? {
            guard let section = source.section(for: indexPath.section),
                  let item = source.item(for: indexPath),
                  let cell = (view.cellForRow(at: indexPath) as? Cell.Listed)?.wrapped
            else { return nil }
            return selectable(cell: cell, with: item, in: section, for: indexPath) ? indexPath : nil
        }
        public final func tableView(
            _ tableView: UITableView,
            didSelectRowAt indexPath: IndexPath
        ) {
            guard let section = source.section(for: indexPath.section),
                  let item = source.item(for: indexPath)
            else { return }
            set(item: item, in: section, selected: true, programatically: false)
        }
        public final func tableView(
            _ tableView: UITableView,
            willDeselectRowAt indexPath: IndexPath
        ) -> IndexPath? {
            guard let section = source.section(for: indexPath.section),
                  let item = source.item(for: indexPath),
                  let cell = (view.cellForRow(at: indexPath) as? Cell.Listed)?.wrapped
            else { return nil}
            return deselectable(cell: cell, with: item, in: section, for: indexPath) ? indexPath : nil
        }
        public final func tableView(
            _ tableView: UITableView,
            didDeselectRowAt indexPath: IndexPath
        ) {
            guard let section = source.section(for: indexPath.section),
                  let item = source.item(for: indexPath)
            else { return }
            set(item: item, in: section, selected: false, programatically: false)
        }
        public final func tableView(
            _ tableView: UITableView,
            willDisplayHeaderView view: UIView,
            forSection section: Int
        ) {
            guard let _section = source.section(for: section),
                  let view = view as? Boundary
            else { return }
            will(display: view, above: _section, at: section)
        }
        public final func tableView(
            _ tableView: UITableView,
            didEndDisplayingHeaderView view: UIView,
            forSection section: Int
        ) {
            guard let _section = source.section(for: section),
                  let view = view as? Boundary
            else { return }
            did(display: view, above: _section, at: section)
        }
        public final func tableView(
            _ tableView: UITableView,
            willDisplayFooterView view: UIView,
            forSection section: Int
        ) {
            guard let _section = source.section(for: section),
                  let view = view as? Boundary
            else { return }
            will(display: view, below: _section, at: section)
        }
        public final func tableView(
            _ tableView: UITableView,
            didEndDisplayingFooterView view: UIView,
            forSection section: Int
        ) {
            guard let _section = source.section(for: section),
                  let view = view as? Boundary
            else { return }
            did(display: view, below: _section, at: section)
        }
        public final func tableView(
            _ tableView: UITableView,
            shouldHighlightRowAt indexPath: IndexPath
        ) -> Bool {
            guard let section = source.section(for: indexPath.section),
                  let item = source.item(for: indexPath),
                  let cell = (view.cellForRow(at: indexPath) as? Cell.Listed)?.wrapped
            else { return false }
            return highlightable(cell: cell, with: item, in: section, for: indexPath)
        }
        public final func tableView(
            _ tableView: UITableView,
            didHighlightRowAt indexPath: IndexPath
        ) {
            guard let section = source.section(for: indexPath.section),
                  let item = source.item(for: indexPath),
                  let cell = (view.cellForRow(at: indexPath) as? Cell.Listed)?.wrapped
            else { return }
            cell.highlighted = true
            cell.set(highlighted: true, animated: true)
            highlighted(cell: cell, with: item, in: section, for: indexPath)
        }
        public final func tableView(
            _ tableView: UITableView,
            didUnhighlightRowAt indexPath: IndexPath
        ) {
            guard let section = source.section(for: indexPath.section),
                  let item = source.item(for: indexPath),
                  let cell = (view.cellForRow(at: indexPath) as? Cell.Listed)?.wrapped
            else { return }
            cell.highlighted = false
            cell.set(highlighted: false, animated: true)
            unhighlighted(cell: cell, with: item, in: section, for: indexPath)
        }
        #if os(tvOS)
        public final func tableView(
            _ tableView: UITableView,
            canFocusRowAt indexPath: IndexPath
        ) -> Bool {
            guard let section = source.section(for: indexPath.section),
                  let style = layout.style(for: section)
            else { return false }
            switch style {
            case .vertical:
                guard let item = source.item(for: indexPath),
                      let cell = (view.cellForRow(at: indexPath) as? Cell.Listed)?.wrapped
                else { return false }
                return focusable(cell: cell, with: item, in: section, for: indexPath)
            case .grid, .horizontal, .custom:
                return false
            }
        }
        public final func tableView(
            _ tableView: UITableView,
            shouldUpdateFocusIn context: UITableViewFocusUpdateContext
        ) -> Bool {
            should(update: FocusUpdateContext(tabled: context))
        }
        public final func tableView(
            _ tableView: UITableView,
            didUpdateFocusIn context: UITableViewFocusUpdateContext,
            with coordinator: UIFocusAnimationCoordinator
        ) {
            lastFocusedIndexPath = context.previouslyFocusedIndexPath
            let focus = FocusUpdateContext(tabled: context)
            update(focus: focus, using: coordinator)
            guard let indexPath = context.nextFocusedIndexPath,
                  let section = source.section(for: indexPath.section),
                  let item = source.item(for: indexPath),
                  let cell = (view.cellForRow(at: indexPath) as? Cell.Listed)?.wrapped
            else { return }
            focused(cell: cell, with: item, in: section, for: indexPath, with: focus, using: coordinator)
        }
        #endif
        public final func scrollViewDidScroll(_ scrollView: UIScrollView) {
            scrolled()
        }
        
        //MARK: - Boundary Delegate
        internal final func selectable(header: Boundary, in section: Int) -> Bool {
            guard let _section = source.section(for: section) else { return false }
            return selectable(header: header, in: _section, at: section)
        }
        internal final func selectable(footer: Boundary, in section: Int) -> Bool {
            guard let _section = source.section(for: section) else { return false }
            return selectable(footer: footer, in: _section, at: section)
        }
        internal final func selected(header: Boundary, in section: Int) {
            guard let _section = source.section(for: section) else { return }
            selected(header: header, in: _section, at: section)
        }
        internal final func selected(footer: Boundary, in section: Int) {
            guard let _section = source.section(for: section) else { return }
            selected(footer: footer, in: _section, at: section)
        }
        internal final func highlightable(header: Boundary, in section: Int) -> Bool {
            guard let _section = source.section(for: section) else { return false }
            return highlightable(header: header, in: _section, at: section)
        }
        internal final func highlightable(footer: Boundary, in section: Int) -> Bool {
            guard let _section = source.section(for: section) else { return false }
            return highlightable(footer: footer, in: _section, at: section)
        }
        internal final func highlighted(header: Boundary, in section: Int) {
            guard let _section = source.section(for: section) else { return }
            highlighted(header: header, in: _section, at: section)
        }
        internal final func unhighlighted(header: Boundary, in section: Int) {
            guard let _section = source.section(for: section) else { return }
            unhighlighted(header: header, in: _section, at: section)
        }
        internal final func highlighted(footer: Boundary, in section: Int) {
            guard let _section = source.section(for: section) else { return }
            highlighted(footer: footer, in: _section, at: section)
        }
        internal final func unhighlighted(footer: Boundary, in section: Int) {
            guard let _section = source.section(for: section) else { return }
            highlighted(footer: footer, in: _section, at: section)
        }
        internal final func focusable(header: Boundary, in section: Int) -> Bool {
            guard let _section = source.section(for: section) else { return false }
            return focusable(header: header, in: _section, at: section)
        }
        internal final func focusable(footer: Boundary, in section: Int) -> Bool {
            guard let _section = source.section(for: section) else { return false }
            return focusable(footer: footer, in: _section, at: section)
        }
        internal final func focused(header: Boundary, in section: Int) {
            guard let _section = source.section(for: section) else { return }
            focused(header: header, in: _section, at: section)
        }
        internal final func focused(footer: Boundary, in section: Int) {
            guard let _section = source.section(for: section) else { return }
            focused(footer: footer, in: _section, at: section)
        }
        
        //MARK: - List Delegate
        open func will(display cell: Cell, with item: Item, in section: Section, for indexPath: IndexPath) {}
        open func end(display cell: Cell, with item: Item, in section: Section, for indexPath: IndexPath) {}
        open func selectable(cell: Cell, with item: Item, in section: Section, for indexPath: IndexPath) -> Bool {
            #if os(tvOS)
            return focusable(cell: cell, with: item, in: section, for: indexPath)
            #else
            return true
            #endif
        }
        open func selected(cell: Cell, with item: Item, in section: Section, for indexPath: IndexPath) {}
        open func deselectable(cell: Cell, with item: Item, in section: Section, for indexPath: IndexPath) -> Bool { return true }
        open func deselected(cell: Cell, with item: Item, in section: Section, for indexPath: IndexPath) { cell.set(selected: false, animated: true) }
        open func didSelect(multiple item: Item, in section: Section, for indexPath: IndexPath) {}
        open func endSelectMultiple(in list: UITableView) {}
         
        open func will(display header: Boundary, above section: Section, at index: Int) {}
        open func did(display header: Boundary, above section: Section, at index: Int) {}
        open func will(display footer: Boundary, below section: Section, at index: Int) {}
        open func did(display footer: Boundary, below section: Section, at index: Int) {}
        
        open func highlightable(cell: Cell, with item: Item, in section: Section, for indexPath: IndexPath) -> Bool { return selectable(cell: cell, with: item, in: section, for: indexPath) }
        open func highlighted(cell: Cell, with item: Item, in section: Section, for indexPath: IndexPath) {}
        open func unhighlighted(cell: Cell, with item: Item, in section: Section, for indexPath: IndexPath) {}
        
        open func will(edit cell: Cell, with item: Item, in section: Section, for indexPath: IndexPath) {}
        open func did(edit cell: Cell, with item: Item, in section: Section, for indexPath: IndexPath) {}

        open func focusable(cell: Cell, with item: Item, in section: Section, for indexPath: IndexPath) -> Bool { return true }
        open func should(update focus: FocusUpdateContext) -> Bool { return true }
        open func update(focus context: FocusUpdateContext, using coordinator: UIFocusAnimationCoordinator) {}
        open func focused(cell: Cell, with item: Item, in section: Section, for indexPath: IndexPath, with context: FocusUpdateContext, using coordinator: UIFocusAnimationCoordinator) {}
        open func indexPathForPreferredFocusedView(in tableView: UITableView) -> IndexPath? {
            return nil
        }
        
        open func selectable(header: Boundary, in section: Section, at index: Int) -> Bool {
            #if os(tvOS)
            return focusable(header: header, in: section, at: index)
            #else
            return false
            #endif
        }
        open func selectable(footer: Boundary, in section: Section, at index: Int) -> Bool {
            #if os(tvOS)
            return focusable(footer: footer, in: section, at: index)
            #else
            return false
            #endif
        }
        open func selected(header: Boundary, in section: Section, at index: Int) {}
        open func selected(footer: Boundary, in section: Section, at index: Int) {}
        open func highlightable(header: Boundary, in section: Section, at index: Int) -> Bool {
            return selectable(header: header, in: section, at: index)
        }
        open func highlightable(footer: Boundary, in section: Section, at index: Int) -> Bool {
            return selectable(footer: footer, in: section, at: index)
        }
        open func highlighted(header: Boundary, in section: Section, at index: Int) {}
        open func unhighlighted(header: Boundary, in section: Section, at index: Int) {}
        open func highlighted(footer: Boundary, in section: Section, at index: Int) {}
        open func unhighlighted(footer: Boundary, in section: Section, at index: Int) {}
        open func focusable(header: Boundary, in section: Section, at index: Int) -> Bool { return false }
        open func focusable(footer: Boundary, in section: Section, at index: Int) -> Bool { return false }
        open func focused(header: Boundary, in section: Section, at index: Int) { }
        open func focused(footer: Boundary, in section: Section, at index: Int) { }
        
        open func scrolled() {}
        
        //MARK: - Managing DataSource
        /// - layout provider: define how to compose your sections and layout items
        /// - source provider: define cells and boundary views
        /// - behaviour provider: define logic of particular section
        public final func set(layout provider: Layout.Provider?, animated: Bool) {
            layout.provider = provider
            source.snapshot.batch(updates: [.refreshSections(source.sections)], animation: animated ? .fade : nil)
        }
        public final func set(source provider: Source.Provider?, animated: Bool) {
            source.provider = provider
            source.snapshot.batch(updates: [.reloadSections(source.sections)], animation: animated ? .fade : nil)
        }
        public final func set(behaviour provider: Behaviour.Provider?) {
            behaviour.provider = provider
        }
        
        public final func dequeue<T: Cell>(
            cell: T.Type,
            for indexPath: IndexPath
        ) -> T? {
            guard let section = source.section(for: indexPath.section),
                  let style = layout.style(for: section)
            else { return nil }
            switch style {
            case .vertical, .custom:
                guard let listed = view.dequeue(cell: cell, for: indexPath) else {
                    lastDequedCell = nil
                    return T(frame: .zero)
                }
                lastDequedCell = listed
                return (listed.wrapped as? T) ?? T(frame: .zero)
            default:
                return grid(for: indexPath.section)?.grid?.dequeue(cell: cell, with: indexPath.item)
            }
        }
        public final func dequeue<T: Boundary>(
            boundary: T.Type
        ) -> T? {
            guard let listed = view.dequeue(boundary) else {
                lastDequedBoundary = nil
                return T(frame: .zero)
            }
            lastDequedBoundary = listed
            return (listed.wrapped as? T) ?? T(frame: .zero)
        }

        //MARK: Override these properties to register
        /// - cells: table view cells and collection view cells
        /// - boundaries: headers and footers
        open var cells: [Cell.Type] {
            return []
        }
        open var boundaries: [Boundary.Type] {
            return []
        }
        
        private func register() {
            cells.forEach{
                view.register($0.self)
            }
            boundaries.forEach {
                view.register($0.self)
            }
        }
        private func wrapper(section: Section, for index: Int) -> Cell.Listed?  {
            let type = Cell.Wrapper<Section, Item>.self
            let wrapper: Cell.Listed? = {
                guard let template = source.identifier(for: section) else {
                    let template = String(describing: type)
                    source.set(identifier: template, for: section)
                    view.register(type, template: template)
                    return view.dequeue(wrapper: type, for: IndexPath(item: 0, section: index), with: template)
                }
                return view.dequeue(wrapper: type, for: IndexPath(item: 0, section: index), with: template)
            }()
            guard let wrapper else { return nil }
            let wrapped: Cell.Wrapper<Section, Item> = {
                guard let wrapped = wrapper.wrapped as? Cell.Wrapper<Section, Item> else {
                    let wrapped = Cell.Wrapper<Section, Item>()
                    wrapper.wrap(cell: wrapped)
                    return wrapped
                }
                return wrapped
            }()
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                wrapped.configure(in: index, parent: self)
            }
            return wrapper
        }
        
        open func update(for traitCollection: UITraitCollection) {}
    }    
}

//MARK: - Source extraction
extension Composition.Manager {
    public final var visibleCells: [Cell] {
        guard let indexPaths = view.indexPathsForVisibleRows else { return [] }
        return indexPaths.reduce(into: Array<Cell>()) { visible, indexPath in
            guard let section = source.section(for: indexPath.section),
                  let style = layout.style(for: section)
            else { return () }
            switch style {
            case .vertical:
                guard let cell = cell(for: indexPath) else { return () }
                visible.append(cell)
            case .grid, .horizontal:
                guard let grid = grid(for: indexPath.section)?.grid else { return () }
                visible.append(contentsOf: grid.view.visibleCells.compactMap{ grid.wrapped(for: $0) })
            case .custom:
                return ()
            }
        }
    }
    public final var configuredCells: [Cell] {
        var cells: [Cell] = []
        for (i, section) in source.sections.enumerated() {
            guard let style = layout.style(for: section) else { continue }
            switch style {
            case .vertical:
                for j in source.items(for: section).indices {
                    guard let cell = cell(for: IndexPath(item: j, section: i)) else { continue }
                    cells.append(cell)
                }
            case .horizontal, .grid:
                guard let grid = grid(for: i)?.grid else { continue }
                cells.append(contentsOf: source.items(for: section).enumerated().compactMap{ grid.cell(for: $0.offset) })
            case .custom:
                continue
            }
        }
        return cells
    }
    public final var visibleIndexPaths: [IndexPath] {
        guard let indexPaths = view.indexPathsForVisibleRows else { return [] }
        return indexPaths.reduce(into: Array<IndexPath>()) { visible, indexPath in
            guard let section = source.section(for: indexPath.section),
                  let style = layout.style(for: section)
            else { return () }
            switch style {
            case .vertical:
                visible.append(indexPath)
            case .grid, .horizontal:
                guard let grid = grid(for: indexPath.section)?.grid else { return () }
                visible.append(contentsOf: grid.view.indexPathsForVisibleItems.map {
                    IndexPath(item: $0.item, section: indexPath.section)
                })
            case .custom:
                return ()
            }
        }
    }
    public final var configuredIndexPaths: [IndexPath] {
        var indexPaths: [IndexPath] = []
        for (i, section) in source.sections.enumerated() {
            guard let style = layout.style(for: section) else { continue }
            switch style {
            case .vertical:
                for j in source.items(for: section).indices {
                    let indexPath = IndexPath(item: j, section: i)
                    if cell(for: indexPath) != nil {
                        indexPaths.append(indexPath)
                    }
                }
            case .horizontal, .grid:
                guard let grid = grid(for: i)?.grid else { continue }
                indexPaths.append(contentsOf: grid.view.indexPathsForVisibleItems.map {
                    IndexPath(item: $0.item, section: i)
                }.filter{ grid.cell(for: $0.item) != nil })
            case .custom:
                continue
            }
        }
        return indexPaths
    }
    public final func cell(for item: Item) -> Cell? {
        guard let section = source.section(for: item),
              let indexPath = source.indexPath(for: item),
              let style = layout.style(for: section)
        else { return nil }
        switch style {
        case .vertical, .custom:
            return cell(for: indexPath)
        case .grid, .horizontal:
            return grid(for: indexPath.section)?.grid?.cell(for: indexPath.item)
        }
    }
    public final func header(for section: Section) -> Boundary? {
        guard let index = source.index(for: section) else { return nil }
        return (view.headerView(forSection: index) as? Boundary.Listed)?.wrapped
    }
    public final func footer(for section: Section) -> Boundary? {
        guard let index = source.index(for: section) else { return nil }
        return (view.footerView(forSection: index) as? Boundary.Listed)?.wrapped
    }
    public final func sectionRect(for index: Int) -> CGRect {
        return view.rect(forSection: index)
    }
    public final func headerRect(for section: Int) -> CGRect {
        return view.rectForHeader(inSection: section)
    }
    public final func footerRect(for section: Int) -> CGRect {
        return view.rectForFooter(inSection: section)
    }
}

extension Composition.Manager {
    public final func set(
        header: UIView,
        height: CGFloat,
        offset: CGPoint = .zero
    ) {
        header.translatesAutoresizingMaskIntoConstraints = true
        header.frame = CGRect(x: offset.x, y: offset.y, width: view.frame.width, height: height)
        view.tableHeaderView = header
    }
    public final func scroll(
        to item: Item,
        position: Composition.ScrollPosition,
        animated: Bool,
        completion: (() -> Void)? = nil
    ) {
        guard let section = source.section(for: item),
              let indexPath = source.indexPath(for: item),
              let style = layout.style(for: section)
        else { return }
        switch style {
        case .vertical:
            let scrollPosition: UITableView.ScrollPosition = {
                switch position {
                case .top   : return .top
                case .middle: return .middle
                case .bottom: return .bottom
                default     : return .none
                }
            }()
            scroll(to: indexPath, at: scrollPosition, animated: animated)
        case .grid, .horizontal:
            let scrollPosition: UICollectionView.ScrollPosition = {
                switch position {
                case .top   : return .top
                case .middle: return {
                    switch style {
                    case .vertical: return .centeredVertically
                    default: return .centeredHorizontally
                    }
                }()
                case .bottom: return .bottom
                case .left  : return .left
                case .right : return .right
                }
            }()
            grid(for: indexPath.section)?.grid?.scroll(to: indexPath.item, at: scrollPosition, animated: animated)
        case .custom:
            return
        }
    }
    public final func select(
        item: Item,
        position: Composition.ScrollPosition?,
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        guard let section = source.section(for: item) else { return }
        if let position {
            scroll(to: item, position: position, animated: animated)
        }
        set(item: item, in: section, selected: true, programatically: true, completion: completion)
    }
    public final func selectAll(animated: Bool = true) {
        source.selectAll()
        source.selected.forEach { select(item: $0, position: nil, animated: true) }
    }
    public final func deselect(
        item: Item,
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        guard let section = source.section(for: item) else { return }
        set(item: item, in: section, selected: false, programatically: true, completion: completion)
    }
    public final func deselectAll(animated: Bool = true) {
        source.selected.forEach { deselect(item: $0, animated: true) }
    }
    internal func set(
        item: Item,
        in section: Section,
        selected: Bool,
        programatically: Bool,
        completion: (() -> Void)? = nil
    ) {
        guard let style = layout.style(for: section),
              let indexPath = source.indexPath(for: item)
        else { return }
        guard selected else {
            guard source.selected(item: item) else { return }
            source.set(item: item, selected: false)
            set(item: item, _item: indexPath.item, section: section, _section: indexPath.section, style: style, selected: false, programatically: programatically, completion: completion)
            return
        }
        guard !source.selected(item: item) else { return }
        if !behaviour.multiselection(section: section) {
            source.items(for: section).enumerated().filter{ source.selected(item: $0.element) }.forEach {
                source.set(item: $0.element, selected: false)
                set(item: $0.element, _item: $0.offset, section: section, _section: indexPath.section, style: style, selected: false, programatically: true)
            }
        }
        source.set(item: item, selected: true)
        set(item: item, _item: indexPath.item, section: section, _section: indexPath.section, style: style, selected: true, programatically: programatically, completion: completion)
    }
    private func set(
        item: Item,
        _item: Int,
        section: Section,
        _section: Int,
        style: Layout.Style,
        selected: Bool,
        programatically: Bool,
        completion: (() -> Void)? = nil
    ) {
        let _indexPath = IndexPath(item: _item, section: _section)
        switch style {
        case .vertical:
            guard let cell = cell(for: _indexPath) else { return }
            set(selected: selected, indexPath: _indexPath)
            set(cell: cell, selected: selected, completion: completion)
            if !programatically {
                selected ? self.selected(cell: cell, with: item, in: section, for: _indexPath) : self.deselected(cell: cell, with: item, in: section, for: _indexPath)
            }
        case .grid:
            guard let grid = grid(for: _section)?.grid,
                  let cell = grid.cell(for: _item)
            else { return }
            grid.set(selected: selected, item: _item)
            set(cell: cell, selected: selected, completion: completion)
            if !programatically {
                selected ? self.selected(cell: cell, with: item, in: section, for: _indexPath) : self.deselected(cell: cell, with: item, in: section, for: _indexPath)
            }
        case .horizontal(_, _, let rows, _):
            switch rows {
            case .finite:
                guard let grid = grid(for: _section)?.grid,
                      let cell = grid.cell(for: _item)
                else { return }
                grid.set(selected: selected, item: _item)
                set(cell: cell, selected: selected, completion: completion)
                if !programatically {
                    selected ? self.selected(cell: cell, with: item, in: section, for: _indexPath) : self.deselected(cell: cell, with: item, in: section, for: _indexPath)
                }
            case .infinite:
                guard let grid = grid(for: _section)?.grid else { return }
                for __item in grid.stride(for: _item) {
                    guard let cell = grid.cell(for: __item) else { continue }
                    grid.set(selected: selected, item: __item)
                    set(cell: cell, selected: selected, completion: completion)
                    if !programatically {
                        let indexPath = IndexPath(item: __item, section: _section)
                        selected ? self.selected(cell: cell, with: item, in: section, for: indexPath) : self.deselected(cell: cell, with: item, in: section, for: indexPath)
                    }
                }
            }
        default:
            break
        }
    }
    internal func set(cell: Cell, selected: Bool, completion: (() -> Void)? = nil) {
        cell.selected = selected
        cell.set(selected: selected, animated: true)
        completion?()
    }
}

extension Composition.Manager {
    internal final func grid(for section: Int) -> Cell.Wrapper<Section, Item>? {
        return (view.cellForRow(at: IndexPath(item: 0, section: section)) as? Cell.Listed)?.wrapped as? Cell.Wrapper<Section, Item>
    }
    internal final func cell(for indexPath: IndexPath) -> Cell? {
        return (view.cellForRow(at: indexPath) as? Cell.Listed)?.wrapped
    }
    internal final func wrapped(for cell: UITableViewCell) -> Cell? {
        return (cell as? Cell.Listed)?.wrapped
    }
    internal final func set(selected: Bool, indexPath: IndexPath, animated: Bool = false) {
        selected ? view.selectRow(at: indexPath, animated: false, scrollPosition: .none) : view.deselectRow(at: indexPath, animated: false)
    }
    internal final func scroll(to indexPath: IndexPath, at position: UITableView.ScrollPosition, animated: Bool) {
        view.scrollToRow(at: indexPath, at: position, animated: animated)
    }
}

public class Composition {
    public struct Scrolling {
        public let vBounce          : Bool
        public let vScroll          : Bool
        public let hBounce          : Bool
        public let hScroll          : Bool

        public init(vBounce: Bool, vScroll: Bool, hBounce: Bool, hScroll: Bool) {
            self.vBounce = vBounce
            self.vScroll = vScroll
            self.hBounce = hBounce
            self.hScroll = hScroll
        }
    }
    public enum ScrollPosition {
        case top
        case middle
        case bottom
        case left
        case right
    }
}
