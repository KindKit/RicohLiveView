//
//  RicohLiveView
//

import UIKit

public extension RicohLiveView {
    
    enum State : Equatable {
        
        case idle
        case connecting
        case streaming
        case error(RicohLiveView.Error)
        
    }
    
}
