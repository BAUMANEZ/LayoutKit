// ___FILEHEADER___

import UIKit
import LayoutKit
import OrderedCollections

extension ___VARIABLE_productName:identifier___List {
    public var _sourceProvider: Source.Provider {
        return Source.Provider(
            cell: { indexPath, section, item in
                return nil
            },
            header: { index, section in
                return nil
            },
            footer: { index, section in
                return nil
            }
        )
    }
}
