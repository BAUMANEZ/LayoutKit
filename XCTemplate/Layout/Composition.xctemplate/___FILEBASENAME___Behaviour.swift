// ___FILEHEADER___

import UIKit
import LayoutKit
import OrderedCollections

extension ___VARIABLE_productName:identifier___List {
    public var _behaviourProvider: Behaviour.Provider {
        return Behaviour.Provider(
            multiselection: { section in
                return false
            }
        )
    }
}
