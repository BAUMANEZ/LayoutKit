//
//  Grid.swift
//
//
//  Created by Арсений Токарев on 19.03.2022.
//

import UIKit
import OrderedCollections

extension Grid {
    internal final class Manager<Section: Hashable, Item: Hashable>: NSObject, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, BoundaryDelegate {
        internal typealias Parent = Composition.Manager<Section, Item>?
        
        internal final let view: UICollectionView
        internal final let _section: Int
        internal final weak var parent: Parent
        internal final weak var pager: Pager?
                
        internal final let multiplier = 1000
        internal final var mod: Int {
            guard let parent, let section = parent.source.section(for: _section) else { return 1 }
            return max(1, parent.source.items(for: section).count)
        }
        
        private var lastDequedCell: Cell.Grided?
                
        //MARK: - Init
        internal init(parent: Parent, section: Int, in content: UIView) {
            let flow = FlowLayout<Section, Item>()
            self.view = UICollectionView(frame: content.frame, collectionViewLayout: flow)
            self.parent = parent
            self._section = section
            super.init()
            flow.grid = self
            setup(in: content)
        }
        
        private func setup(in content: UIView) {
            guard let parent,
                  let section = parent.source.section(for: _section),
                  let style = parent.layout.style(for: section)
            else { return }
            view.register(Cell.self)
            register()
            view.delegate = self
            view.dataSource = self
            
            view.clipsToBounds = false
            view.backgroundColor = .clear
            view.insetsLayoutMarginsFromSafeArea = false
            view.contentInsetAdjustmentBehavior = .never
            view.allowsMultipleSelection = true
            
            switch style {
            case .vertical, .grid, .custom:
                view.alwaysBounceVertical = false
                view.showsVerticalScrollIndicator = false
                view.alwaysBounceHorizontal = false
                view.showsHorizontalScrollIndicator = false
                view.isScrollEnabled = false
                (view.collectionViewLayout as? UICollectionViewFlowLayout)?.scrollDirection = .vertical
            case .horizontal(_, _, let rows, _):
                switch rows {
                case .infinite(let scrolling), .finite(_, let scrolling):
                    switch scrolling {
                    case .centerted:
                        view.decelerationRate = .fast
                    default:
                        break
                    }
                }
                view.alwaysBounceVertical = false
                view.showsVerticalScrollIndicator = false
                view.alwaysBounceHorizontal = true
                view.showsHorizontalScrollIndicator = false
                view.isScrollEnabled = true
                (view.collectionViewLayout as? UICollectionViewFlowLayout)?.scrollDirection = .horizontal
            }
            
            parent.source.items(for: section).enumerated().filter{ parent.source.selected(item: $0.element) }.forEach {
                view.selectItem(at: IndexPath(item: $0.offset, section: 0), animated: false, scrollPosition: [])
            }
            
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
            
            view.topAnchor.constraint(equalTo: content.topAnchor).isActive = true
            view.leftAnchor.constraint(equalTo: content.leftAnchor).isActive = true
            view.rightAnchor.constraint(equalTo: content.rightAnchor).isActive = true
            view.bottomAnchor.constraint(equalTo: content.bottomAnchor).isActive = true
        }
        
        internal final func stride(for item: Int) -> StrideTo<Int> {
            let mod = mod
            return Swift.stride(from: item, to: mod*multiplier, by: mod)
        }
        
        //MARK: - Data
        internal final func numberOfSections(
            in collectionView: UICollectionView
        ) -> Int {
            return 1
        }
        internal final func collectionView(
            _ collectionView: UICollectionView,
            numberOfItemsInSection section: Int
        ) -> Int {
            guard let parent,
                  let section = parent.source.section(for: _section),
                  let style = parent.layout.style(for: section)
            else { return .zero }
            switch style {
            case .horizontal(_, _, let rows, _):
                switch rows {
                case .finite:
                    return parent.source.items(for: section).count
                case .infinite:
                    return multiplier*parent.source.items(for: section).count
                }
            default:
                return parent.source.items(for: section).count
            }
        }
        internal final func collectionView(
            _ collectionView: UICollectionView,
            cellForItemAt indexPath: IndexPath
        ) -> UICollectionViewCell {
            let _indexPath = IndexPath(item: indexPath.item%mod, section: _section)
            guard let parent,
                  let cell = parent.source.cell(for: _indexPath) as? Cell,
                  let grided = lastDequedCell ?? collectionView.dequeue(cell: cell, for: indexPath)
            else { return collectionView.dequeue(cell: Cell(), for: indexPath) ?? UICollectionViewCell() }
            lastDequedCell = nil
            cell.selected = parent.source.selected(indexPath: _indexPath)
            cell.set(selected: cell.selected, animated: false)
            if cell.dequeID != grided.wrapped?.dequeID {
                grided.wrap(cell: cell)
            }
            return grided
        }
        
        //MARK: - Layout
        internal final func collectionView(
            _ collectionView: UICollectionView,
            layout collectionViewLayout: UICollectionViewLayout,
            sizeForItemAt indexPath: IndexPath
        ) -> CGSize {
            guard let parent,
                  let section = parent.source.section(for: _section),
                  let item = parent.source.item(for: IndexPath(item: indexPath.item%mod, section: _section))
            else { return .zero }
            return parent.layout.size(for: item, in: section)
        }
        internal final func collectionView(
            _ collectionView: UICollectionView,
            layout collectionViewLayout: UICollectionViewLayout,
            insetForSectionAt section: Int
        ) -> UIEdgeInsets {
            guard let parent,
                  let section = parent.source.section(for: _section)
            else { return .zero }
            return parent.layout.insets(for: section)
        }
        internal final func collectionView(
            _ collectionView: UICollectionView,
            layout collectionViewLayout: UICollectionViewLayout,
            minimumLineSpacingForSectionAt section: Int
        ) -> CGFloat {
            guard let parent,
                  let section = parent.source.section(for: _section)
            else { return .zero }
            return parent.layout.indent(for: section)
        }
        internal final func collectionView(
            _ collectionView: UICollectionView,
            layout collectionViewLayout: UICollectionViewLayout,
            minimumInteritemSpacingForSectionAt section: Int
        ) -> CGFloat {
            guard let parent,
                  let section = parent.source.section(for: _section)
            else { return .zero }
            return parent.layout.spacing(for: section)
        }
        
        //MARK: - Delegate
        internal final func collectionView(
            _ collectionView: UICollectionView,
            willDisplay cell: UICollectionViewCell,
            forItemAt indexPath: IndexPath
        ) {
            guard let parent,
                  let section = parent.source.section(for: _section),
                  let item = parent.source.item(for: IndexPath(item: indexPath.item%mod, section: _section)),
                  let cell = (cell as? Cell.Grided)?.wrapped
            else { return }
            parent.will(display: cell, with: item, in: section, for: indexPath)
        }
        internal final func collectionView(
            _ collectionView: UICollectionView,
            didEndDisplaying cell: UICollectionViewCell,
            forItemAt indexPath: IndexPath
        ) {
            guard let parent,
                  let section = parent.source.section(for: _section),
                  let item = parent.source.item(for: IndexPath(item: indexPath.item%mod, section: _section)),
                  let cell = (cell as? Cell.Grided)?.wrapped
            else { return }
            parent.end(display: cell, with: item, in: section, for: indexPath)
        }
        internal final func collectionView(
            _ collectionView: UICollectionView,
            shouldSelectItemAt indexPath: IndexPath
        ) -> Bool {
            guard let parent,
                  let section = parent.source.section(for: _section),
                  let item = parent.source.item(for: IndexPath(item: indexPath.item%mod, section: _section)),
                  let cell = cell(for: indexPath.item)
            else { return false }
            return parent.selectable(cell: cell, with: item, in: section, for: indexPath)
        }
        internal final func collectionView(
            _ collectionView: UICollectionView,
            didSelectItemAt indexPath: IndexPath
        ) {
            let _indexPath = IndexPath(item: indexPath.item%mod, section: _section)
            guard let parent,
                  let section = parent.source.section(for: _section),
                  let item = parent.source.item(for: _indexPath)
            else { return }
            parent.set(item: item, in: section, selected: true, programatically: false)
        }
        internal final func collectionView(
            _ collectionView: UICollectionView,
            shouldDeselectItemAt indexPath: IndexPath
        ) -> Bool {
            let _indexPath = IndexPath(item: indexPath.item%mod, section: _section)
            guard let parent,
                  let section = parent.source.section(for: _section),
                  let item = parent.source.item(for: _indexPath),
                  let cell = cell(for: indexPath.item)
            else { return false }
            return parent.deselectable(cell: cell, with: item, in: section, for: _indexPath)
        }
        internal final func collectionView(
            _ collectionView: UICollectionView,
            didDeselectItemAt indexPath: IndexPath
        ) {
           let _indexPath = IndexPath(item: indexPath.item%mod, section: _section)
            guard let parent,
                  let section = parent.source.section(for: _section),
                  let item = parent.source.item(for: _indexPath)
            else { return }
            parent.set(item: item, in: section, selected: false, programatically: false)
        }
        internal final func collectionView(
            _ collectionView: UICollectionView,
            shouldHighlightItemAt indexPath: IndexPath
        ) -> Bool {
            guard let parent,
                  let section = parent.source.section(for: _section),
                  let item = parent.source.item(for: IndexPath(item: indexPath.item%mod, section: _section)),
                  let cell = cell(for: indexPath.item)
            else { return false }
            return parent.highlightable(cell: cell, with: item, in: section, for: indexPath)
        }
        internal final func collectionView(
            _ collectionView: UICollectionView,
            didHighlightItemAt indexPath: IndexPath
        ) {
            guard let parent,
                  let section = parent.source.section(for: _section),
                  let item = parent.source.item(for: IndexPath(item: indexPath.item%mod, section: _section)),
                  let cell = cell(for: indexPath.item)
            else { return }
            cell.highlighted = true
            cell.set(highlighted: true, animated: true)
            parent.highlighted(cell: cell, with: item, in: section, for: indexPath)
        }
        internal final func collectionView(
            _ collectionView: UICollectionView,
            didUnhighlightItemAt indexPath: IndexPath
        ) {
            guard let parent,
                  let section = parent.source.section(for: _section),
                  let item = parent.source.item(for: IndexPath(item: indexPath.item%mod, section: _section)),
                  let cell = cell(for: indexPath.item)
            else { return }
            cell.highlighted = false
            cell.set(highlighted: false, animated: true)
            parent.unhighlighted(cell: cell, with: item, in: section, for: indexPath)
        }
        internal final func collectionView(
            _ collectionView: UICollectionView,
            canFocusItemAt indexPath: IndexPath
        ) -> Bool {
            guard let parent,
                  let section = parent.source.section(for: _section),
                  let item = parent.source.item(for: IndexPath(item: indexPath.item%mod, section: _section)),
                  let cell = cell(for: indexPath.item)
            else { return false }
            return parent.focusable(cell: cell, with: item, in: section, for: indexPath)
        }
        internal final func collectionView(
            _ collectionView: UICollectionView,
            shouldUpdateFocusIn context: UICollectionViewFocusUpdateContext
        ) -> Bool {
            return parent?.should(update: FocusUpdateContext(grided: context, actual: _section)) == true
        }
        internal final func collectionView(
            _ collectionView: UICollectionView,
            didUpdateFocusIn context: UICollectionViewFocusUpdateContext,
            with coordinator: UIFocusAnimationCoordinator
        ) {
            guard let parent else { return }
            let focus = FocusUpdateContext(grided: context, actual: _section)
            parent.update(focus: focus, using: coordinator)
            guard let indexPath = context.nextFocusedIndexPath,
                  let section = parent.source.section(for: _section),
                  let style = parent.layout.style(for: section),
                  let item = parent.source.item(for: IndexPath(
                    item: indexPath.item%mod,
                    section: _section
                  )),
                  let cell = cell(for: indexPath.item)
            else { return }
            switch style {
            case .vertical, .grid, .custom:
                view.isScrollEnabled = true
            case .horizontal(_, _, let rows, _):
                switch rows {
                case .finite(_, let scrolling), .infinite(let scrolling):
                    switch scrolling {
                    case .automatic:
                        view.isScrollEnabled = true
                    case .centerted:
                        view.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
                        view.isScrollEnabled = false
                    }
                }
            }
            parent.focused(cell: cell, with: item, in: section, for: indexPath, with: FocusUpdateContext(grided: context, actual: _section), using: coordinator)
        }
        internal final func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard let parent,
                  let section = parent.source.section(for: _section)
            else { return }
            parent.source.save(offset: scrollView.contentOffset, in: section)
            if pager != nil,
               let center = view.indexPathForItem(
                at: CGPoint(x: view.frame.midX+view.contentOffset.x, y: view.frame.midY/2)
            ){
                parent.source.save(page: center.item, in: section)
            }
            parent.scrolled()
        }
        
        //MARK: - Boundary Delegate
        internal final func selectable(header: Boundary, in section: Int) -> Bool {
            guard let parent,
                  let section = parent.source.section(for: _section)
            else { return false }
            return parent.selectable(header: header, in: section, at: _section)
        }
        internal final func selectable(footer: Boundary, in section: Int) -> Bool {
            guard let parent,
                  let section = parent.source.section(for: _section)
            else { return false }
            return parent.selectable(footer: footer, in: section, at: _section)
        }
        internal final func selected(header: Boundary, in section: Int) {
            guard let parent,
                  let section = parent.source.section(for: _section)
            else { return }
            parent.selected(header: header, in: section, at: _section)
        }
        internal final func selected(footer: Boundary, in section: Int) {
            guard let parent,
                  let section = parent.source.section(for: _section)
            else { return }
            parent.selected(footer: footer, in: section, at: _section)
        }
        internal final func highlightable(header: Boundary, in section: Int) -> Bool {
            guard let parent,
                  let section = parent.source.section(for: _section)
            else { return false }
            return parent.highlightable(header: header, in: section, at: _section)
        }
        internal final func highlightable(footer: Boundary, in section: Int) -> Bool {
            guard let parent,
                  let section = parent.source.section(for: _section)
            else { return false }
            return parent.highlightable(footer: footer, in: section, at: _section)
        }
        internal final func highlighted(header: Boundary, in section: Int) {
            guard let parent,
                  let section = parent.source.section(for: _section)
            else { return }
            parent.highlighted(header: header, in: section, at: _section)
        }
        internal final func unhighlighted(header: Boundary, in section: Int) {
            guard let parent,
                  let section = parent.source.section(for: _section)
            else { return }
            parent.unhighlighted(header: header, in: section, at: _section)
        }
        internal final func highlighted(footer: Boundary, in section: Int) {
            guard let parent,
                  let section = parent.source.section(for: _section)
            else { return }
            parent.highlighted(footer: footer, in: section, at: _section)
        }
        internal final func unhighlighted(footer: Boundary, in section: Int) {
            guard let parent,
                  let section = parent.source.section(for: _section)
            else { return }
            parent.highlighted(footer: footer, in: section, at: _section)
        }
        internal final func focusable(header: Boundary, in section: Int) -> Bool {
            guard let parent,
                  let section = parent.source.section(for: _section)
            else { return false }
            return parent.focusable(header: header, in: section, at: _section)
        }
        internal final func focusable(footer: Boundary, in section: Int) -> Bool {
            guard let parent,
                    let section = parent.source.section(for: _section)
            else { return false }
            return parent.focusable(footer: footer, in: section, at: _section)
        }
        internal final func focused(header: Boundary, in section: Int) {
            guard let parent,
                    let section = parent.source.section(for: _section)
            else { return }
            parent.focused(header: header, in: section, at: _section)
        }
        internal final func focused(footer: Boundary, in section: Int) {
            guard let parent,
                  let section = parent.source.section(for: _section)
            else { return }
            parent.focused(footer: footer, in: section, at: _section)
        }
        
        private func register() {
            guard let parent else { return }
            parent.cells.forEach{
                view.register($0.self)
            }
        }
    }
}

extension Grid.Manager {
    internal final  func cell(for item: Int) -> Cell? {
        return (view.cellForItem(at: IndexPath(item: item, section: 0)) as? Cell.Grided)?.wrapped
    }
    internal final func wrapped(for cell: UICollectionViewCell) -> Cell? {
        return (cell as? Cell.Grided)?.wrapped
    }
    internal final func set(selected: Bool, item: Int, animated: Bool = false) {
        let indexPath = IndexPath(item: item, section: 0)
        selected ? view.selectItem(at: indexPath, animated: animated, scrollPosition: []) : view.deselectItem(at: indexPath, animated: animated)
    }
    internal final func scroll(to item: Int, at position: UICollectionView.ScrollPosition, animated: Bool) {
        view.scrollToItem(at: IndexPath(item: item, section: 0), at: position, animated: animated)
    }
    internal final func dequeue<T: Cell>(
        cell: T.Type,
        with item: Int
    ) -> T? {
        guard let grided = view.dequeue(cell: cell, for: IndexPath(item: item%mod, section: 0)) else {
            lastDequedCell = nil
            return T(frame: .zero)
        }
        lastDequedCell = grided
        return (grided.wrapped as? T) ?? T(frame: .zero)
    }
}

internal struct Grid {}
