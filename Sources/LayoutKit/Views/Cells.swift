//
//  Cells.swift
//  
//
//  Created by Арсений Токарев on 19.03.2022.
//

import UIKit

open class Cell: UIView, Compositional {
    //MARK: Main properties
    /// - identifier: override this property for your custom cell. This property is used when dequeueing cell
    /// - scheme: use this property together with paint(scheme:) function to apply colors to your cell
    open class var identifier: String {
        return "defaultCell"
    }
    internal var _identifier: String {
        return Self.identifier
    }
    internal weak var wrapper: UIView?
    public let content = UIView()
    
    public internal(set) var selected: Bool = false
    public internal(set) var highlighted: Bool = false
    public internal(set) var focusing: Bool = false
    
    open func prepareForReuse() {}
    
    //MARK: Preconfiguration
    /// - insets: define your custom content's insets
    open var insets: UIEdgeInsets {
        return .zero
    }
    
    public init() {
        super.init(frame: .zero)
        setupContent()
        setup()
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //MARK: Entry point for cell layout cofiguration
    open func setup() {}
    private func setupContent() {
        clipsToBounds = false
        content.clipsToBounds = false
        backgroundColor = .clear
        content.backgroundColor = .clear
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        
        let insets = insets
        content.topAnchor.constraint(equalTo: topAnchor, constant: insets.top).isActive = true
        content.leftAnchor.constraint(equalTo: leftAnchor, constant: insets.left).isActive = true
        content.rightAnchor.constraint(equalTo: rightAnchor, constant: -insets.right).isActive = true
        content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -insets.bottom).isActive = true
    }
    
    open func set(selected: Bool, animated: Bool = true) {}
    open func set(highlighted: Bool, animated: Bool = true) {
        UIView.animate(withDuration: animated ? 0.5 : 0, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.25, options: [.allowUserInteraction, .curveLinear], animations: {
            self.content.transform = highlighted ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
        }, completion: nil)
    }
    open func set(focused: Bool, context: UIFocusUpdateContext, coordinator: UIFocusAnimationCoordinator) {}
}

extension Cell {
    internal class Wrapper<Section: Hashable, Item: Hashable>: Cell {
        internal typealias Child  = Grid.Manager<Section, Item>
        internal typealias Parent = Composition.Manager<Section, Item>
        
        override class var identifier: String {
            return "wrapperCell"
        }
        
        internal private(set) var grid: Child?
        
        override func prepareForReuse() {
            super.prepareForReuse()
            clear()
        }
        
        internal func clear() {
            grid?.view.removeFromSuperview()
            grid = nil
        }
        
        internal func configure(in section: Int, parent: Parent) {
            self.grid = Child(parent: parent, section: section, in: content)
        }
        
        internal func set(offset: CGPoint?) {
            grid?.view.contentOffset = offset ?? CGPoint(x: 15000, y: 0)
        }
    }
}

extension Cell {
    internal class Listed: UITableViewCell {
        internal var wrapped: Cell?
                
        override func prepareForReuse() {
            super.prepareForReuse()
            wrapped?.wrapper = nil
            wrapped?.prepareForReuse()
            wrapped?.removeFromSuperview()
            wrapped = nil
        }
        
        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            clipsToBounds = false
            contentView.clipsToBounds = false
            #if os(iOS)
            separatorInset = .zero
            #endif
            selectionStyle = .none
            backgroundColor = .clear
            focusStyle = .custom
            if #available(tvOS 14.0, iOS 14.0, *) {
                backgroundConfiguration = .clear()
            }
            self.indentationWidth = 0
            indentationLevel = 0
            contentScaleFactor = 1
            
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        internal func wrap(cell: Cell) {
            self.wrapped = cell
            cell.wrapper = self
            cell.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(cell)
            
            cell.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
            cell.leftAnchor.constraint(equalTo: contentView.leftAnchor).isActive = true
            cell.rightAnchor.constraint(equalTo: contentView.rightAnchor).isActive = true
            cell.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
        }
        
        override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
            wrapped?.focusing = isFocused
            wrapped?.set(focused: isFocused, context: context, coordinator: coordinator)
        }
    }
}

extension Cell {
    internal class Grided: UICollectionViewCell {
        internal var wrapped: Cell?
        
        override func prepareForReuse() {
            super.prepareForReuse()
            wrapped?.wrapper = nil
            wrapped?.prepareForReuse()
            wrapped?.removeFromSuperview()
            wrapped = nil
        }
        
        internal override init(frame: CGRect) {
            super.init(frame: frame)
            clipsToBounds = false
            backgroundColor = .clear
        }
        
        public required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        internal func wrap(cell: Cell) {
            self.wrapped = cell
            cell.wrapper = self
            cell.translatesAutoresizingMaskIntoConstraints = false
            addSubview(cell)
            
            cell.topAnchor.constraint(equalTo: topAnchor).isActive = true
            cell.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
            cell.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
            cell.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        }
        
        override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
            wrapped?.focusing = isFocused
            wrapped?.set(focused: isFocused, context: context, coordinator: coordinator)
        }
    }
}

public extension UITableViewCell {
    var root: UIView? {
        return contentView.subviews.first(where: { $0.isKind(of: Cell.self) })
    }
}
public extension UICollectionViewCell {
    var root: UIView? {
        return subviews.first(where: { $0.isKind(of: Cell.self) })
    }
}

extension UITableView {
    internal func register(_ cell: Cell.Type) {
        register(Cell.Listed.self, forCellReuseIdentifier: cell.identifier)
    }
    internal func register(_ wrapper: Cell.Type, template: String? = nil) {
        if let template = template {
            register(Cell.Listed.self, forCellReuseIdentifier: wrapper.identifier + "_" + template)
        } else {
            register(wrapper.self)
        }
    }
    internal func dequeue(cell: Cell, for indexPath: IndexPath) -> Cell.Listed? {
        return dequeueReusableCell(withIdentifier: cell._identifier, for: indexPath) as? Cell.Listed
    }
    internal func dequeue(wrapper: Cell, for indexPath: IndexPath, with template: String? = nil) -> Cell.Listed? {
        if let template = template {
            return dequeueReusableCell(withIdentifier: wrapper._identifier + "_" + template, for: indexPath) as? Cell.Listed
        } else {
            return dequeue(cell: wrapper, for: indexPath)
        }
    }
}

extension UICollectionView {
    internal func register(_ cell: Cell.Type) {
        register(Cell.Grided.self, forCellWithReuseIdentifier: cell.identifier)
    }
    internal func register(_ cell: Cell.Type, template: String) {
        register(Cell.Grided.self, forCellWithReuseIdentifier: cell.identifier + "_" + template)
    }
    internal func dequeue(cell: Cell, for indexPath: IndexPath) -> Cell.Grided? {
        return dequeueReusableCell(withReuseIdentifier: cell._identifier, for: indexPath) as? Cell.Grided
    }
    internal func dequeue(cell: Cell, template: String, for indexPath: IndexPath) -> Cell.Grided? {
        return dequeueReusableCell(withReuseIdentifier: cell._identifier + "_" + template, for: indexPath) as? Cell.Grided
    }
}
