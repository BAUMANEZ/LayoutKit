//
//  CompositionBehaviour.swift
//  
//
//  Created by Арсений Токарев on 08.07.2022.
//

import UIKit
import OrderedCollections

//MARK: - Behaviour
extension Composition {
    public final class Behaviour<Section: Hashable, Item: Hashable> {
        internal weak var manager: Manager<Section, Item>?
        internal weak var layout : Layout<Section, Item>?
        internal var provider    : Provider?
        
        //MARK: - Methods
        /// - multiselection: default is false
        /// - persistance: persist section when data source tries deleting it
        public func multiselection(section: Section) -> Bool {
            return provider?.multiselection?(section) ?? false
        }
        public func persistant(item: Item, in section: Section) -> Bool {
            return provider?.persistance?(item, section) ?? false
        }
        
        internal init(manager: Manager<Section, Item>? = nil) {
            self.manager = manager
        }
    }
}

extension Composition.Behaviour {
    public class Provider {
        public typealias Multiselection = (Section) -> Bool
        public typealias Persistance = (Item, Section) -> Bool
        
        public var multiselection: Multiselection?
        public var persistance: Persistance?
        
        public init(multiselection: Multiselection? = nil, persistance: Persistance? = nil) {
            self.multiselection = multiselection
            self.persistance = persistance
        }
    }
}
