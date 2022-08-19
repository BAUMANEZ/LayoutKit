//
//  Protocols.swift
//  
//
//  Created by Арсений Токарев on 23.05.2022.
//

import UIKit

public protocol Selectable {
    func set(selected: Bool, animated: Bool)
}
public protocol Pager: AnyObject {
    func set(page: Int)
}
public protocol Dequeueable: NSObjectProtocol {
    static var identifier: String { get }
}
public protocol Highlightable: UIView {
    func set(highlighted: Bool, animated: Bool)
}
public protocol Editable: UIView {
    func set(editing: Bool, animated: Bool)
}
public protocol Focusable: UIView {
    func set(focused: Bool, context: UIFocusUpdateContext, coordinator: UIFocusAnimationCoordinator)
}

public protocol Compositional: Dequeueable, Highlightable, Selectable, Focusable {}
