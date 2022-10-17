//
//  Boundary.swift
//  
//
//  Created by Арсений Токарев on 19.03.2022.
//

import UIKit

internal protocol BoundaryDelegate: AnyObject {
    func selectable(header: Boundary, in section: Int) -> Bool
    func selectable(footer: Boundary, in section: Int) -> Bool
    func selected(header: Boundary, in section: Int)
    func selected(footer: Boundary, in section: Int)
    func highlightable(header: Boundary, in section: Int) -> Bool
    func highlightable(footer: Boundary, in section: Int) -> Bool
    func highlighted(header: Boundary, in section: Int)
    func unhighlighted(header: Boundary, in section: Int)
    func highlighted(footer: Boundary, in section: Int)
    func unhighlighted(footer: Boundary, in section: Int)
    func focusable(header: Boundary, in section: Int) -> Bool
    func focusable(footer: Boundary, in section: Int) -> Bool
    func focused(header: Boundary, in section: Int)
    func focused(footer: Boundary, in section: Int)
}

open class Boundary: UIView, Dequeueable, Highlightable, Focusable {
    internal let dequeID = UUID()
    
    //MARK: Main properties
    /// - identifier: override this property for your custom boundary view. This property is used when dequeueing view
    /// - scheme: use this property together with paint(scheme:) function to apply colors to your view
    open class var identifier: String {
        return String(describing: Self.self)
    }
    internal var _identifier: String {
        return Self.identifier
    }
    public var content = UIView()
    
    public internal(set) var highlighted: Bool = false
    public internal(set) var focusing: Bool = false
    
    //MARK: Preconfiguration
    /// - insets: define your custom content's insets
    public var insets: UIEdgeInsets {
        return .zero
    }
    
    open func prepareForReuse() {}
    
    public override required init(frame: CGRect = .zero) {
        super.init(frame: .zero)
        setupContent()
        setup()
    }
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //MARK: Entry point for view layout cofiguration
    open func setup() {}
    private func setupContent() {
        content.backgroundColor = .clear
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        
        let insets = insets
        content.topAnchor.constraint(equalTo: topAnchor, constant: insets.top).isActive = true
        content.leftAnchor.constraint(equalTo: leftAnchor, constant: insets.left).isActive = true
        content.rightAnchor.constraint(equalTo: rightAnchor, constant: -insets.right).isActive = true
        content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -insets.bottom).isActive = true
    }
    
    open func selected() {}
    open func set(focused: Bool, context: UIFocusUpdateContext, coordinator: UIFocusAnimationCoordinator) {}
    open func set(highlighted: Bool, animated: Bool = true) {
        UIView.animate(withDuration: animated ? 0.5 : 0, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.25, options: [.allowUserInteraction, .curveLinear]) {
            self.content.transform = highlighted ? CGAffineTransform(scaleX: 0.985, y: 0.985) : .identity
        }
    }
}

extension Boundary {
    internal final class Listed: UITableViewHeaderFooterView {
        internal var wrapped: Boundary?
        internal weak var delegate: BoundaryDelegate?
        internal var section: Int?
        private var isHeader = true
        
        override var canBecomeFocused: Bool {
            guard let section = section, let delegate = delegate, let wrapped = wrapped else { return false }
            return isHeader ? delegate.focusable(header: wrapped, in: section) : delegate.focusable(footer: wrapped, in: section)
        }

        override init(reuseIdentifier: String?) {
            super.init(reuseIdentifier: reuseIdentifier)
            touches()
        }
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        internal override func prepareForReuse() {
            super.prepareForReuse()
            delegate = nil
            wrapped?.prepareForReuse()
        }
        
        internal func wrap(boundary: Boundary, isHeader: Bool) {
            self.isHeader = isHeader
            wrapped?.removeFromSuperview()
            wrapped = boundary
            boundary.translatesAutoresizingMaskIntoConstraints = false
            addSubview(boundary)
            
            let top = boundary.topAnchor.constraint(equalTo: topAnchor);
            top.priority = .required; top.isActive = true
            let left = boundary.leftAnchor.constraint(equalTo: leftAnchor);
            left.priority = .required; left.isActive = true
            let right = boundary.rightAnchor.constraint(equalTo: rightAnchor);
            right.priority = .defaultHigh; right.isActive = true
            let bottom = boundary.bottomAnchor.constraint(equalTo: bottomAnchor);
            bottom.priority = .defaultHigh; bottom.isActive = true
        }
        
        public override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
            guard let delegate = delegate, let section = section, let wrapped = wrapped else { return }
            isHeader ? delegate.focused(header: wrapped, in: section) : delegate.focused(footer: wrapped, in: section)
            wrapped.focusing = isFocused
            wrapped.set(focused: isFocused, context: context, coordinator: coordinator)
        }
        
        private func touches() {
            isUserInteractionEnabled = true
        }
        
        #if os(tvOS)
        internal override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            super.pressesBegan(presses, with: event)
            guard let delegate = delegate, let section = section, let wrapped = wrapped else { return }
            guard isHeader ? delegate.highlightable(header: wrapped, in: section) : delegate.highlightable(footer: wrapped, in: section) else { return }
            guard let type = presses.first?.type else { return }
            switch type {
            case .select:
                isHeader ? delegate.highlighted(header: wrapped, in: section) : delegate.highlighted(footer: wrapped, in: section)
                wrapped.set(highlighted: true, animated: true)
            default:
                break
            }
        }
        internal override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            super.pressesEnded(presses, with: event)
            guard let delegate = delegate,
                  let section = section,
                  let wrapped = wrapped,
                  let type = presses.first?.type
            else { return }
            switch type {
            case .select:
                if isHeader ? delegate.selectable(header: wrapped, in: section) : delegate.selectable(footer: wrapped, in: section) {
                    isHeader ? delegate.selected(header: wrapped, in: section) : delegate.selected(footer: wrapped, in: section)
                    wrapped.selected()
                }
                guard isHeader ? delegate.highlightable(header: wrapped, in: section) : delegate.highlightable(footer: wrapped, in: section) else { return }
                isHeader ? delegate.unhighlighted(header: wrapped, in: section) : delegate.unhighlighted(footer: wrapped, in: section)
                wrapped.set(highlighted: false, animated: true)
            default:
                break
            }
        }
        #else
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesBegan(touches, with: event)
            guard let delegate = delegate, let section = section, let wrapped = wrapped else { return }
            guard isHeader ? delegate.highlightable(header: wrapped, in: section) : delegate.highlightable(footer: wrapped, in: section) else { return }
            isHeader ? delegate.highlighted(header: wrapped, in: section) : delegate.highlighted(footer: wrapped, in: section)
            wrapped.set(highlighted: true, animated: true)
        }
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesEnded(touches, with: event)
            guard let delegate = delegate,
                  let section = section,
                  let wrapped = wrapped
            else { return }
            if isHeader ? delegate.selectable(header: wrapped, in: section) : delegate.selectable(footer: wrapped, in: section) {
                isHeader ? delegate.selected(header: wrapped, in: section) : delegate.selected(footer: wrapped, in: section)
                wrapped.selected()
            }
            guard isHeader ? delegate.highlightable(header: wrapped, in: section) : delegate.highlightable(footer: wrapped, in: section) else { return }
            isHeader ? delegate.unhighlighted(header: wrapped, in: section) : delegate.unhighlighted(footer: wrapped, in: section)
            wrapped.set(highlighted: false, animated: true)
        }
        #endif
    }
}

//MARK: Internally views are wrapped in tableHeaderFooterView
extension UITableView {
    internal func register(_ view: Boundary.Type) {
        register(Boundary.Listed.self, forHeaderFooterViewReuseIdentifier: view.identifier)
    }
    internal func dequeue(_ view: Boundary) -> Boundary.Listed? {
        dequeueReusableHeaderFooterView(withIdentifier: view._identifier) as? Boundary.Listed
    }
    internal func dequeue(_ view: Boundary.Type) -> Boundary.Listed? {
        dequeueReusableHeaderFooterView(withIdentifier: view.identifier) as? Boundary.Listed
    }
}
