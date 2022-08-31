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
        
        public var scroll: UIScrollView {
            return view
        }
        public var contentOffset: CGPoint {
            return view.contentOffset
        }
        
        public var visibleCells: [Cell] {
            guard let indexPaths = view.indexPathsForVisibleRows else { return [] }
            return indexPaths.reduce(into: Array<Cell>()) { visible, indexPath in
                guard let section = source.section(for: indexPath.section),
                      let style = layout.style(for: section)
                else { return () }
                switch style {
                case .vertical:
                    guard let tabled = (view.cellForRow(at: indexPath) as? Cell.Listed)?.wrapped else { return () }
                    visible.append(tabled)
                case .grid, .horizontal:
                    guard let grid = ((view.cellForRow(at: indexPath) as? Cell.Listed)?.wrapped as? Cell.Wrapper<Section, Item>)?.grid else { return () }
                    let grided = grid.view.visibleCells.compactMap{ ($0 as? Cell.Grided)?.wrapped }
                    visible.append(contentsOf: grided)
                case .custom:
                    return ()
                }
            }
        }
        public var configuredCells: [Cell] {
            var cells: [Cell] = []
            for (i, section) in source.sections.enumerated() {
                guard let style = layout.style(for: section) else { continue }
                switch style {
                case .vertical:
                    for j in source.items(for: section).indices {
                        guard let cell = (view.cellForRow(at: IndexPath(item: j, section: i)) as? Cell.Listed)?.wrapped else { continue }
                        cells.append(cell)
                    }
                case .horizontal, .grid:
                    guard let grid = ((view.cellForRow(at: IndexPath(item: 0, section: i)) as? Cell.Listed)?.wrapped as? Cell.Wrapper<Section, Item>)?.grid?.view else { continue }
                    for j in source.items(for: section).indices {
                        guard let cell = (grid.cellForItem(at: IndexPath(item: j, section: 0)) as? Cell.Grided)?.wrapped  else { continue }
                        cells.append(cell)
                    }
                case .custom:
                    continue
                }
            }
            return cells
        }
        
        public var visibleIndexPaths: [IndexPath] {
            guard let indexPaths = view.indexPathsForVisibleRows else { return [] }
            return indexPaths.reduce(into: Array<IndexPath>()) { visible, indexPath in
                guard let section = source.section(for: indexPath.section),
                      let style = layout.style(for: section)
                else { return () }
                switch style {
                case .vertical:
                    visible.append(indexPath)
                case .grid, .horizontal:
                    guard let grid = ((view.cellForRow(at: indexPath) as? Cell.Listed)?.wrapped as? Cell.Wrapper<Section, Item>)?.grid else { return () }
                    visible.append(contentsOf: grid.view.indexPathsForVisibleItems.map {
                        IndexPath(item: $0.item, section: indexPath.section)
                    })
                case .custom:
                    return ()
                }
            }
        }
        public var configuredIndexPaths: [IndexPath] {
            var indexPaths: [IndexPath] = []
            for (i, section) in source.sections.enumerated() {
                guard let style = layout.style(for: section) else { continue }
                switch style {
                case .vertical:
                    for j in source.items(for: section).indices {
                        let indexPath = IndexPath(item: j, section: i)
                        guard view.cellForRow(at: indexPath) != nil else { continue }
                        indexPaths.append(indexPath)
                    }
                case .horizontal, .grid:
                    guard let grid = ((view.cellForRow(at: IndexPath(item: 0, section: i)) as? Cell.Listed)?.wrapped as? Cell.Wrapper<Section, Item>)?.grid?.view else { continue }
                    for j in source.items(for: section).indices {
                        guard grid.cellForItem(at: IndexPath(item: j, section: 0)) != nil else { continue }
                        indexPaths.append(IndexPath(item: j, section: i))
                    }
                case .custom:
                    continue
                }
            }
            return indexPaths
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
        
        public func set(header: UIView, height: CGFloat, offset: CGPoint = .zero) {
            header.translatesAutoresizingMaskIntoConstraints = true
            header.frame = CGRect(x: offset.x, y: offset.y, width: view.frame.width, height: height)
            view.tableHeaderView = header
        }
        
        public func cell(for item: Item) -> Cell? {
            guard let section = source.section(for: item),
                  let indexPath = source.indexPath(for: item),
                  let style = layout.style(for: section)
            else { return nil }
            switch style {
            case .vertical:
                return (view.cellForRow(at: indexPath) as? Cell.Listed)?.wrapped
            case .grid, .horizontal:
                guard let wrapper = (view.cellForRow(at: IndexPath(item: 0, section: indexPath.section)) as? Cell.Listed)?.wrapped as? Cell.Wrapper<Section, Item> else { return nil }
                return (wrapper.grid?.view.cellForItem(at: IndexPath(item: indexPath.item, section: 0)) as? Cell.Grided)?.wrapped
            case .custom:
                return nil
            }
        }
        
        public func header(for section: Section) -> Boundary? {
            guard let index = source.index(for: section) else { return nil }
            return (view.headerView(forSection: index) as? Boundary.Listed)?.wrapped
        }
        
        public func footer(for section: Section) -> Boundary? {
            guard let index = source.index(for: section) else { return nil }
            return (view.footerView(forSection: index) as? Boundary.Listed)?.wrapped
        }
        
        public func select(item: Item, position: ScrollPosition?, animated: Bool = true, completion: (() -> Void)? = nil) {
            guard let section = source.section(for: item) else { return }
            if let position = position {
                scroll(to: item, position: position, animated: animated)
            }
            set(item: item, in: section, selected: true, programatically: true, completion: completion)
            completion?()
        }
        public func selectAll(animated: Bool = true) {
            source.selectAll()
            source.selected.forEach { select(item: $0, position: nil, animated: true) }
        }
        
        public func deselect(item: Item, animated: Bool = true, completion: (() -> Void)? = nil) {
            guard let section = source.section(for: item) else { return }
            set(item: item, in: section, selected: false, programatically: true, completion: completion)
        }
        public func deselectAll(animated: Bool = true) {
            source.selected.forEach { deselect(item: $0, animated: true) }
        }
        
        public func scroll(to item: Item, position: ScrollPosition, animated: Bool, completion: (() -> Void)? = nil) {
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
                view.scrollToRow(at: indexPath, at: scrollPosition, animated: animated)
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
                let grid = ((view.cellForRow(at: IndexPath(item: 0, section: indexPath.section)) as? Cell.Listed)?.wrapped as? Cell.Wrapper<Section, Item>)?.grid?.view
                let _indexPath = IndexPath(item: indexPath.item, section: 0)
                grid?.scrollToItem(at: _indexPath, at: scrollPosition, animated: animated)
            case .custom:
                return
            }
        }
        
        //MARK: UITableViewDataSource
        public func numberOfSections(in tableView: UITableView) -> Int {
            return source.sections.count
        }
        public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            guard let section = source.section(for: section) else { return .zero }
            switch layout.style(for: section) {
            case .vertical:
                return source.items(for: section).count
            default:
                return 1
            }
        }
        
        public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            guard let section = source.section(for: indexPath.section) else { return UITableViewCell() }
            switch layout.style(for: section) {
            case .vertical(_, let separator):
                guard let cell = source.cell(for: indexPath) as? Cell,
                      let listed = tableView.dequeue(cell: cell, for: indexPath)
                else { return UITableViewCell()  }
                cell.selected = source.selected(indexPath: indexPath)
                cell.set(selected: cell.selected, animated: false)
                listed.wrap(cell: cell, separator: separator?.view)
                return listed
            case .custom:
                guard let cell = source.cell(for: indexPath) as? Cell,
                      let listed = tableView.dequeue(cell: cell, for: indexPath)
                else { return UITableViewCell()  }
                cell.selected = source.selected(indexPath: indexPath)
                cell.set(selected: cell.selected, animated: false)
                listed.wrap(cell: cell, separator: nil)
                return listed
            default:
                let template = validate(wrapper: section)
                let wrapped = Cell.Wrapper<Section, Item>()
                #if os(iOS)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    wrapped.configure(in: indexPath.section, parent: self)
                }
                #else
                wrapped.configure(in: indexPath.section, parent: self)
                #endif
                guard let wrapper = tableView.dequeue(wrapper: wrapped, for: indexPath, with: template) else { return UITableViewCell() }
                wrapper.wrap(cell: wrapped, separator: nil)
                return wrapper
            }
        }
        public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
            guard let boundary = source.header(for: section),
                  let listed = tableView.dequeue(boundary)
            else { return nil }
            listed.delegate = self
            listed.wrap(boundary: boundary, in: section, isHeader: true)
            return listed
        }
        public func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
            guard let boundary = source.footer(for: section),
                  let listed = tableView.dequeue(boundary)
            else { return nil }
            listed.delegate = self
            listed.wrap(boundary: boundary, in: section, isHeader: false)
            return listed
        }
        
        //MARK: - UITableViewLayout
        public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
            guard let section = source.section(for: indexPath.section),
                  let style = layout.style(for: section)
            else { return .zero }
            switch style {
            case .grid, .horizontal:
                return layout.height(for: section)
            case .vertical(_, let separator):
                guard let item = source.item(for: indexPath) else { return .zero }
                return layout.height(for: item, in: section)+(separator?.height ?? .zero)
            case .custom(let height):
                return height
            }
        }
        public func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
            guard let section = source.section(for: indexPath.section),
                  let style = layout.style(for: section)
            else { return .zero }
            switch style {
            case .grid, .horizontal:
                return layout.height(for: section)
            case .vertical(_, let separator):
                guard let item = source.item(for: indexPath) else { return .zero }
                return layout.height(for: item, in: section)+(separator?.height ?? .zero)
            case .custom(let height):
                return height
            }
        }
        public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
            guard let section = source.section(for: section) else { return .zero }
            return layout.header(for: section)
        }
        public func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
            guard let section = source.section(for: section) else { return .zero }
            return layout.header(for: section)
        }
        public func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
            guard let section = source.section(for: section) else { return .zero }
            return layout.footer(for: section)
        }
        public func tableView(_ tableView: UITableView, estimatedHeightForFooterInSection section: Int) -> CGFloat {
            guard let section = source.section(for: section) else { return .zero }
            return layout.footer(for: section)
        }
        
        //MARK: - UITableViewDelegate
        public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
            guard let section = source.section(for: indexPath.section),
                  let item = source.item(for: indexPath),
                  let cell = (cell as? Cell.Listed)?.wrapped
            else { return }
            (cell as? Cell.Wrapper<Section, Item>)?.grid?.view.setContentOffset(source.offset(in: section) ?? .zero, animated: false)
            will(display: cell, with: item, in: section, for: indexPath)
        }
        public func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
            guard let section = source.section(for: indexPath.section),
                  let item = source.item(for: indexPath),
                  let cell = (cell as? Cell.Listed)?.wrapped
            else { return }
            layout.calculated(height: cell.bounds.height, for: item, in: section)
            end(display: cell, with: item, in: section, for: indexPath)
        }
        public func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
            guard let section = source.section(for: indexPath.section),
                  let item = source.item(for: indexPath),
                  let cell = (view.cellForRow(at: indexPath) as? Cell.Listed)?.wrapped
            else { return nil }
            return selectable(cell: cell, with: item, in: section, for: indexPath) ? indexPath : nil
        }
        
        public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            guard let section = source.section(for: indexPath.section),
                  let item = source.item(for: indexPath)
            else { return }
            set(item: item, in: section, selected: true, programatically: false)
        }
        public func tableView(_ tableView: UITableView, willDeselectRowAt indexPath: IndexPath) -> IndexPath? {
            guard let section = source.section(for: indexPath.section),
                  let item = source.item(for: indexPath),
                  let cell = (view.cellForRow(at: indexPath) as? Cell.Listed)?.wrapped
            else { return nil}
            return deselectable(cell: cell, with: item, in: section, for: indexPath) ? indexPath : nil
        }
        public func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
            guard let section = source.section(for: indexPath.section),
                  let item = source.item(for: indexPath)
            else { return }
            set(item: item, in: section, selected: false, programatically: false)
        }
        public func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
            guard let _section = source.section(for: section),
                  let view = view as? Boundary
            else { return }
            will(display: view, above: _section, at: section)
        }
        public func tableView(_ tableView: UITableView, didEndDisplayingHeaderView view: UIView, forSection section: Int) {
            guard let _section = source.section(for: section),
                  let view = view as? Boundary
            else { return }
            did(display: view, above: _section, at: section)
        }
        public func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
            guard let _section = source.section(for: section),
                  let view = view as? Boundary
            else { return }
            will(display: view, below: _section, at: section)
        }
        public func tableView(_ tableView: UITableView, didEndDisplayingFooterView view: UIView, forSection section: Int) {
            guard let _section = source.section(for: section),
                  let view = view as? Boundary
            else { return }
            did(display: view, below: _section, at: section)
        }
        
        public func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
            guard let section = source.section(for: indexPath.section),
                  let item = source.item(for: indexPath),
                  let cell = (view.cellForRow(at: indexPath) as? Cell.Listed)?.wrapped
            else { return false }
            return highlightable(cell: cell, with: item, in: section, for: indexPath)
        }
        public func tableView(_ tableView: UITableView, didHighlightRowAt indexPath: IndexPath) {
            guard let section = source.section(for: indexPath.section),
                  let item = source.item(for: indexPath),
                  let cell = (view.cellForRow(at: indexPath) as? Cell.Listed)?.wrapped
            else { return }
            cell.highlighted = true
            cell.set(highlighted: true, animated: true)
            highlighted(cell: cell, with: item, in: section, for: indexPath)
        }
        public func tableView(_ tableView: UITableView, didUnhighlightRowAt indexPath: IndexPath) {
            guard let section = source.section(for: indexPath.section),
                  let item = source.item(for: indexPath),
                  let cell = (view.cellForRow(at: indexPath) as? Cell.Listed)?.wrapped
            else { return }
            cell.highlighted = false
            cell.set(highlighted: false, animated: true)
            unhighlighted(cell: cell, with: item, in: section, for: indexPath)
        }
        
        #if os(tvOS)
        public func tableView(_ tableView: UITableView, canFocusRowAt indexPath: IndexPath) -> Bool {
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
        public func tableView(_ tableView: UITableView, shouldUpdateFocusIn context: UITableViewFocusUpdateContext) -> Bool {
            should(update: FocusUpdateContext(tabled: context))
        }
        public func tableView(_ tableView: UITableView, didUpdateFocusIn context: UITableViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
            #if os(tvOS)
            lastFocusedIndexPath = context.previouslyFocusedIndexPath
            #endif
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
        
        public func scrollViewDidScroll(_ scrollView: UIScrollView) {
            scrolled()
        }
        
        //MARK: - Boundary Delegate
        internal func selectable(header: Boundary, in section: Int) -> Bool {
            guard let _section = source.section(for: section) else { return false }
            return selectable(header: header, in: _section, at: section)
        }
        internal func selectable(footer: Boundary, in section: Int) -> Bool {
            guard let _section = source.section(for: section) else { return false }
            return selectable(footer: footer, in: _section, at: section)
        }
        internal func selected(header: Boundary, in section: Int) {
            guard let _section = source.section(for: section) else { return }
            selected(header: header, in: _section, at: section)
        }
        internal func selected(footer: Boundary, in section: Int) {
            guard let _section = source.section(for: section) else { return }
            selected(footer: footer, in: _section, at: section)
        }
        internal func highlightable(header: Boundary, in section: Int) -> Bool {
            guard let _section = source.section(for: section) else { return false }
            return highlightable(header: header, in: _section, at: section)
        }
        internal func highlightable(footer: Boundary, in section: Int) -> Bool {
            guard let _section = source.section(for: section) else { return false }
            return highlightable(footer: footer, in: _section, at: section)
        }
        internal func highlighted(header: Boundary, in section: Int) {
            guard let _section = source.section(for: section) else { return }
            highlighted(header: header, in: _section, at: section)
        }
        internal func unhighlighted(header: Boundary, in section: Int) {
            guard let _section = source.section(for: section) else { return }
            unhighlighted(header: header, in: _section, at: section)
        }
        internal func highlighted(footer: Boundary, in section: Int) {
            guard let _section = source.section(for: section) else { return }
            highlighted(footer: footer, in: _section, at: section)
        }
        internal func unhighlighted(footer: Boundary, in section: Int) {
            guard let _section = source.section(for: section) else { return }
            highlighted(footer: footer, in: _section, at: section)
        }
        internal func focusable(header: Boundary, in section: Int) -> Bool {
            guard let _section = source.section(for: section) else { return false }
            return focusable(header: header, in: _section, at: section)
        }
        internal func focusable(footer: Boundary, in section: Int) -> Bool {
            guard let _section = source.section(for: section) else { return false }
            return focusable(footer: footer, in: _section, at: section)
        }
        internal func focused(header: Boundary, in section: Int) {
            guard let _section = source.section(for: section) else { return }
            focused(header: header, in: _section, at: section)
        }
        internal func focused(footer: Boundary, in section: Int) {
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
        public func set(layout provider: Layout.Provider?, animated: Bool) {
            layout.provider = provider
            source.snapshot.batch(updates: [.refresh], animation: animated ? .fade : nil)
        }
        public func set(source provider: Source.Provider?, animated: Bool) {
            source.provider = provider
            source.snapshot.batch(updates: [.reloadSections(source.sections)], animation: animated ? .fade : nil)
        }
        public func set(behaviour provider: Behaviour.Provider?) {
            behaviour.provider = provider
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
        private func validate(wrapper: Section) -> String  {
            guard let template = source.identifier(for: wrapper) else {
                let template = String(describing: wrapper)
                source.set(identifier: template, for: wrapper)
                view.register(Cell.Wrapper<Section, Item>.self, template: template)
                return template
            }
            return template
        }
        
        open func update(for traitCollection: UITraitCollection) {}
    }    
}

internal extension Composition.Manager {
    func set(item: Item, in section: Section, selected: Bool, programatically: Bool, completion: (() -> Void)? = nil) {
        guard let style = layout.style(for: section),
              let indexPath = source.indexPath(for: item)
        else { return }
        guard selected else {
            guard source.selected(item: item) else { return }
            source.set(item: item, selected: selected)
            switch style {
            case .vertical:
                view.deselectRow(at: indexPath, animated: false)
                guard let cell = (view.cellForRow(at: indexPath) as? Cell.Listed)?.wrapped else { return }
                set(cell: cell, selected: selected, completion: completion)
                if !programatically { deselected(cell: cell, with: item, in: section, for: indexPath) }
            case .grid:
                guard let grid = ((view.cellForRow(at: IndexPath(item: 0, section: indexPath.section)) as? Cell.Listed)?.wrapped as? Cell.Wrapper<Section, Item>)?.grid?.view else { return }
                let _indexPath = IndexPath(item: indexPath.item, section: 0)
                grid.deselectItem(at: _indexPath, animated: false)
                guard let cell = (grid.cellForItem(at: _indexPath) as? Cell.Grided)?.wrapped else { return }
                set(cell: cell, selected: selected, completion: completion)
                if !programatically { deselected(cell: cell, with: item, in: section, for: indexPath) }
            case .horizontal(_, _, let rows, _):
                guard let grid = ((view.cellForRow(at: IndexPath(item: 0, section: indexPath.section)) as? Cell.Listed)?.wrapped as? Cell.Wrapper<Section, Item>)?.grid else { return }
                switch rows {
                case .finite:
                    let _indexPath = IndexPath(item: indexPath.item, section: 0)
                    grid.view.deselectItem(at: _indexPath, animated: false)
                    guard let cell = (grid.view.cellForItem(at: _indexPath) as? Cell.Grided)?.wrapped else { return }
                    set(cell: cell, selected: selected, completion: completion)
                    if !programatically { self.deselected(cell: cell, with: item, in: section, for: indexPath) }
                case .infinite:
                    for _item in grid.stride(for: indexPath.item) {
                        let _indexPath = IndexPath(item: _item, section: 0)
                        grid.view.deselectItem(at: _indexPath, animated: false)
                        guard let cell = (grid.view.cellForItem(at: _indexPath) as? Cell.Grided)?.wrapped else { continue }
                        set(cell: cell, selected: selected, completion: completion)
                        if !programatically { self.deselected(cell: cell, with: item, in: section, for: indexPath) }
                    }
                }
            default:
                break
            }
            return
        }
        guard !source.selected(item: item) else { return }
        if !behaviour.multiselection(section: section) {
            source.items(for: section).forEach{
                guard source.selected(item: $0) else { return }
                set(item: $0, in: section, selected: false, programatically: true)
            }
        }
        source.set(item: item, selected: selected)
        switch style {
        case .vertical:
            view.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            guard let cell = (view.cellForRow(at: indexPath) as? Cell.Listed)?.wrapped else { return }
            set(cell: cell, selected: selected, completion: completion)
            if !programatically { self.selected(cell: cell, with: item, in: section, for: indexPath) }
        case .grid:
            let _indexPath = IndexPath(item: indexPath.item, section: 0)
            guard let grid = ((view.cellForRow(at: IndexPath(item: 0, section: indexPath.section)) as? Cell.Listed)?.wrapped as? Cell.Wrapper<Section, Item>)?.grid?.view else { return }
            grid.selectItem(at: _indexPath, animated: false, scrollPosition: [])
            guard let cell = (grid.cellForItem(at: _indexPath) as? Cell.Grided)?.wrapped else { return }
            set(cell: cell, selected: selected, completion: completion)
            if !programatically { self.selected(cell: cell, with: item, in: section, for: indexPath) }
        case .horizontal(_, _, let rows, _):
            guard let grid = ((view.cellForRow(at: IndexPath(item: 0, section: indexPath.section)) as? Cell.Listed)?.wrapped as? Cell.Wrapper<Section, Item>)?.grid else { return }
            switch rows {
            case .finite:
                let _indexPath = IndexPath(item: indexPath.item, section: 0)
                grid.view.selectItem(at: _indexPath, animated: false, scrollPosition: [])
                guard let cell = (grid.view.cellForItem(at: _indexPath) as? Cell.Grided)?.wrapped else { return }
                set(cell: cell, selected: selected, completion: completion)
                if !programatically { self.selected(cell: cell, with: item, in: section, for: indexPath) }
            case .infinite:
                for _item in grid.stride(for: indexPath.item) {
                    let _indexPath = IndexPath(item: _item, section: 0)
                    grid.view.selectItem(at: _indexPath, animated: false, scrollPosition: [])
                    guard let cell = (grid.view.cellForItem(at: _indexPath) as? Cell.Grided)?.wrapped else { continue }
                    set(cell: cell, selected: selected, completion: completion)
                    if !programatically { self.selected(cell: cell, with: item, in: section, for: indexPath) }
                }
            }
        default:
            break
        }
    }
    func set(cell: Cell, selected: Bool, completion: (() -> Void)? = nil) {
        cell.selected = selected
        cell.set(selected: selected, animated: true)
        completion?()
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
