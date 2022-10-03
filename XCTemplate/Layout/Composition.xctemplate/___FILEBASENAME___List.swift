// ___FILEHEADER___

import UIKit
import LayoutKit
import OrderedCollections

public class ___VARIABLE_productName:identifier___List: Composition.Manager<___VARIABLE_sectionName___, ___VARIABLE_itemName___> {
    public override var insets: UIEdgeInsets {
        return .zero
    }
    
    public override init(in content: UIView) {
        super.init(in: content)
        setProviders()
    }
    
    public func set(sections: OrderedSet<___VARIABLE_sectionName___>, animated: Bool = true) {
        source.snapshot.batch(updates: [
            .setSections(sections, items: { $0.items })
        ], animation: animated ? .fade : nil)
    }
    public func reload(animated: Bool) {
        source.snapshot.batch(updates: [.reloadSections(source.sections)], animation: animated ? .fade : nil)
    }
    public func clear(animated: Bool) {
        source.snapshot.batch(updates: [.deleteSections(source.sections)], animation: animated ? .fade : nil)
    }
    
    private func setProviders() {
        set(layout: _layoutProvider, animated: false)
        set(source: _sourceProvider, animated: false)
        set(behaviour: _behaviourProvider)
    }
    
    public override var cells: [LayoutKit.Cell.Type] {
        return [
        
        ]
    }
    public override var boundaries: [LayoutKit.Boundary.Type] {
        return [
        
        ]
    }
}
