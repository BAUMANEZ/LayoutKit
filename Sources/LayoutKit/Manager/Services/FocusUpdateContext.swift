//
//  FocusUpdateContext.swift
//  
//
//  Created by Арсений Токарев on 25.05.2022.
//

import UIKit

public class FocusUpdateContext {
    public let indexPath: FocusedProperty<IndexPath>
    public let view     : FocusedProperty<UIView>
    public let item     : FocusedProperty<UIFocusItem>
    
    internal init(tabled: UITableViewFocusUpdateContext) {
        self.indexPath = FocusedProperty<IndexPath>(next: tabled.nextFocusedIndexPath, previous: tabled.previouslyFocusedIndexPath)
        self.view = FocusedProperty<UIView>(next: tabled.nextFocusedView, previous: tabled.previouslyFocusedView)
        self.item = FocusedProperty<UIFocusItem>(next: tabled.nextFocusedItem, previous: tabled.previouslyFocusedItem)
    }
    internal init(grided: UICollectionViewFocusUpdateContext, actual section: Int) {
        let previousIndexPath: IndexPath? = {
            guard let indexPath = grided.previouslyFocusedIndexPath else { return nil }
            return IndexPath(item: indexPath.item, section: section)
        }()
        let nextIndexPath: IndexPath? = {
            guard let indexPath = grided.nextFocusedIndexPath else { return nil }
            return IndexPath(item: indexPath.item, section: section)
        }()
        self.indexPath = FocusedProperty<IndexPath>(next: nextIndexPath, previous: previousIndexPath)
        self.view = FocusedProperty<UIView>(next: grided.nextFocusedView, previous: grided.previouslyFocusedView)
        self.item = FocusedProperty<UIFocusItem>(next: grided.nextFocusedItem, previous: grided.previouslyFocusedItem)
    }
}

extension FocusUpdateContext {
    public class FocusedProperty<T> {
        public let next: T?
        public let previous: T?
        
        internal init(next: T?, previous: T?) {
            self.next = next
            self.previous = previous
        }
        public convenience init() {
            self.init(next: nil, previous: nil)
        }
    }
}
