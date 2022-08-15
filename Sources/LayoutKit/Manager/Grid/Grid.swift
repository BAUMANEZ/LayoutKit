//
//  Grid.swift
//  
//
//  Created by Арсений Токарев on 19.03.2022.
//

import UIKit
import OrderedCollections

extension Grid {
    internal class Manager<Section: Hashable, Item: Hashable>: NSObject, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
        internal typealias Parent = Composition.Manager<Section, Item>?
        
        internal let view: UICollectionView
        internal let _section: Int
        internal weak var parent: Parent
        internal weak var pager: Pager?
        
        internal let multiplier = 1000
        internal var mod: Int {
            guard let parent = parent, let section = parent.source.section(for: _section) else { return 1 }
            return parent.source.items(for: section).count
        }
                
        //MARK: - Init
        internal init(parent: Parent, section: Int, in content: UIView) {
            self.view = UICollectionView(frame: content.frame, collectionViewLayout: UICollectionViewFlowLayout())
            self.parent = parent
            self._section = section
            super.init()
            setup(in: content)
        }
        
        private func setup(in content: UIView) {
            guard let parent = parent,
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
                view.alwaysBounceVertical = false
                view.showsVerticalScrollIndicator = false
                view.alwaysBounceHorizontal = true
                view.showsHorizontalScrollIndicator = true
                view.isScrollEnabled = true
                (view.collectionViewLayout as? UICollectionViewFlowLayout)?.scrollDirection = .horizontal
                if rows == .infinite {
                    view.reloadData()
                    view.scrollToItem(at: IndexPath(item: parent.source.items(for: section).count*multiplier/2, section: 0), at: .centeredHorizontally, animated: false)
                }
            }
            
            parent.source.items(for: section).enumerated().forEach { index, item in
                guard parent.source.selected(item: item) else { return }
                view.selectItem(at: IndexPath(item: index, section: 0), animated: false, scrollPosition: [])
            }
            
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
            
            view.topAnchor.constraint(equalTo: content.topAnchor).isActive = true
            view.leftAnchor.constraint(equalTo: content.leftAnchor).isActive = true
            view.rightAnchor.constraint(equalTo: content.rightAnchor).isActive = true
            view.bottomAnchor.constraint(equalTo: content.bottomAnchor).isActive = true
        }
        
        internal func stride(for item: Int) -> StrideTo<Int> {
            let mod = mod
            return Swift.stride(from: item, to: mod*multiplier, by: mod)
        }
        
        //MARK: - Data
        internal func numberOfSections(in collectionView: UICollectionView) -> Int {
            return 1
        }
        internal func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            guard let parent = parent,
                  let section = parent.source.section(for: _section),
                  let style = parent.layout.style(for: section)
            else { return .zero }
            switch style {
            case .horizontal(_, _, let rows, _):
                return (rows == .infinite ? multiplier : 1)*parent.source.items(for: section).count
            default:
                return parent.source.items(for: section).count
            }
        }
        internal func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let _indexPath = IndexPath(item: indexPath.item%mod, section: _section)
            guard let parent = parent,
                  let cell = parent.source.cell(for: _indexPath) as? Cell,
                  let grided = collectionView.dequeue(cell: cell, for: indexPath)
            else { return collectionView.dequeue(cell: Cell(), for: indexPath) ?? UICollectionViewCell() }
            cell.selected = parent.source.selected(indexPath: _indexPath)
            cell.set(selected: cell.selected, animated: false)
            grided.wrap(cell: cell)
            return grided
        }
        
        //MARK: - Layout
        internal func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
            guard let parent = parent,
                  let section = parent.source.section(for: _section),
                  let item = parent.source.item(for: IndexPath(item: indexPath.item%mod, section: _section))
            else { return .zero }
            return parent.layout.size(for: item, in: section)
        }
        internal func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
            guard let parent = parent,
                  let section = parent.source.section(for: _section)
            else { return .zero }
            return parent.layout.insets(for: section)
        }
        internal func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
            guard let parent = parent,
                  let section = parent.source.section(for: _section)
            else { return .zero }
            return parent.layout.indent(for: section)
        }
        internal func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
            guard let parent = parent,
                  let section = parent.source.section(for: _section)
            else { return .zero }
            return parent.layout.spacing(for: section)
        }
        
        //MARK: - Delegate
        internal func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
            guard let parent = parent,
                  let section = parent.source.section(for: _section),
                  let item = parent.source.item(for: IndexPath(item: indexPath.item%mod, section: _section)),
                  let cell = (cell as? Cell.Grided)?.wrapped
            else { return }
            parent.will(display: cell, with: item, in: section, for: indexPath)
        }
        internal func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
            guard let parent = parent,
                  let section = parent.source.section(for: _section),
                  let item = parent.source.item(for: IndexPath(item: indexPath.item%mod, section: _section)),
                  let cell = (cell as? Cell.Grided)?.wrapped
            else { return }
            parent.end(display: cell, with: item, in: section, for: indexPath)
        }
        internal func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
            guard let parent = parent,
                  let section = parent.source.section(for: _section),
                  let item = parent.source.item(for: IndexPath(item: indexPath.item%mod, section: _section)),
                  let cell = (view.cellForItem(at: indexPath) as? Cell.Grided)?.wrapped
            else { return false }
            return parent.selectable(cell: cell, with: item, in: section, for: indexPath)
        }
        internal func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            let _indexPath = IndexPath(item: indexPath.item%mod, section: _section)
            guard let parent = parent,
                  let section = parent.source.section(for: _section),
                  let item = parent.source.item(for: _indexPath)
            else { return }
            parent.set(item: item, in: section, selected: true, programatically: false)
        }
        internal func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
            let _indexPath = IndexPath(item: indexPath.item%mod, section: _section)
            guard let parent = parent,
                  let section = parent.source.section(for: _section),
                  let item = parent.source.item(for: _indexPath),
                  let cell = (view.cellForItem(at: indexPath) as? Cell.Grided)?.wrapped
            else { return false }
            return parent.deselectable(cell: cell, with: item, in: section, for: _indexPath)
        }
        internal func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
           let _indexPath = IndexPath(item: indexPath.item%mod, section: _section)
            guard let parent = parent,
                  let section = parent.source.section(for: _section),
                  let item = parent.source.item(for: _indexPath)
            else { return }
            parent.set(item: item, in: section, selected: false, programatically: false)
        }
        internal func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
            guard let parent = parent,
                  let section = parent.source.section(for: _section),
                  let item = parent.source.item(for: IndexPath(item: indexPath.item%mod, section: _section)),
                  let cell = (view.cellForItem(at: indexPath) as? Cell.Grided)?.wrapped
            else { return false }
            return parent.highlightable(cell: cell, with: item, in: section, for: indexPath)
        }
        internal func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
            guard let parent = parent,
                  let section = parent.source.section(for: _section),
                  let item = parent.source.item(for: IndexPath(item: indexPath.item%mod, section: _section)),
                  let cell = (view.cellForItem(at: indexPath) as? Cell.Grided)?.wrapped
            else { return }
            cell.highlighted = true
            cell.set(highlighted: true, animated: true)
            parent.highlighted(cell: cell, with: item, in: section, for: indexPath)
        }
        internal func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
            guard let parent = parent,
                  let section = parent.source.section(for: _section),
                  let item = parent.source.item(for: IndexPath(item: indexPath.item%mod, section: _section)),
                  let cell = (view.cellForItem(at: indexPath) as? Cell.Grided)?.wrapped
            else { return }
            cell.highlighted = false
            cell.set(highlighted: false, animated: true)
            parent.unhighlighted(cell: cell, with: item, in: section, for: indexPath)
        }
        internal func collectionView(_ collectionView: UICollectionView, canFocusItemAt indexPath: IndexPath) -> Bool {
            guard let parent = parent,
                  let section = parent.source.section(for: _section),
                  let item = parent.source.item(for: IndexPath(item: indexPath.item%mod, section: _section)),
                  let cell = (view.cellForItem(at: indexPath) as? Cell.Grided)?.wrapped
            else { return false }
            return parent.focusable(cell: cell, with: item, in: section, for: indexPath)
        }
        internal func collectionView(_ collectionView: UICollectionView, shouldUpdateFocusIn context: UICollectionViewFocusUpdateContext) -> Bool {
            return parent?.should(update: FocusUpdateContext(grided: context, actual: _section)) == true
        }
        internal func collectionView(_ collectionView: UICollectionView, didUpdateFocusIn context: UICollectionViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
            guard let parent = parent else { return }
            let focus = FocusUpdateContext(grided: context, actual: _section)
            parent.update(focus: focus, using: coordinator)
            guard let indexPath = context.nextFocusedIndexPath,
                  let section = parent.source.section(for: _section),
                  let item = parent.source.item(for: IndexPath(item: indexPath.item%mod
                                                               , section: _section)),
                  let cell = (view.cellForItem(at: indexPath) as? Cell.Grided)?.wrapped
            else { return }
            parent.focused(cell: cell, with: item, in: section, for: indexPath, with: FocusUpdateContext(grided: context, actual: _section), using: coordinator)
        }
        internal func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard let parent = parent,
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
        
        private func register() {
            guard let parent = parent else { return }
            parent.cells.forEach{
                view.register($0.self)
            }
        }
    }
}

internal struct Grid {}
