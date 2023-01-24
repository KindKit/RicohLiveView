//
//  RicohLiveView
//

import UIKit
import RicohLiveViewStream

public protocol IRicohLiveViewDelegate : AnyObject {
    
    func didChange(_ view: RicohLiveView, state: RicohLiveView.State)
    
}

public final class RicohLiveView : UIImageView {
    
    public weak var delegate: IRicohLiveViewDelegate?
    public var sessionId: String?
    public private(set) var state: State
    private let _stream: RicohLiveViewStream
    
    public override init(frame: CGRect) {
        self.state = .idle
        self._stream = RicohLiveViewStream()
        super.init(frame: frame)
        self._setup()
    }
    
    public required init?(coder: NSCoder) {
        self.state = .idle
        self._stream = RicohLiveViewStream()
        super.init(coder: coder)
        self._setup()
    }
    
}

private extension RicohLiveView {
    
    func _setup() {
        self._stream.setDelegate({ [weak self] frame, error in
            guard let self = self else { return }
            if let error = error {
                self._apply(error)
            } else if let frame = frame {
                self._apply(frame)
            } else {
                self._apply(NSError(domain: NSURLErrorDomain, code: NSURLErrorUnknown))
            }
        })
    }
    
    func _set(state: State) {
        guard self.state != state else { return }
        self.state = state
        self.delegate?.didChange(self, state: state)
    }
    
    func _apply(_ frame: UIImage) {
        switch self.state {
        case .idle, .connecting, .error:
            self._set(state: .streaming)
        case .streaming:
            break
        }
        self.image = frame
    }
    
    func _apply(_ error: Swift.Error) {
        var ricohLiveViewError: Error
        let nsError = error as NSError
        switch nsError.domain {
        case NSURLErrorDomain:
            switch nsError.code {
            case -1: ricohLiveViewError = .canNotPerformOperation
            case -999: ricohLiveViewError = .canceled
            default: ricohLiveViewError = .unknown
            }
        default: ricohLiveViewError = .unknown
        }
        self._set(state: .error(ricohLiveViewError))
    }
    
}

public extension RicohLiveView {
    
    func startStreaming(host: String = "192.168.1.1") {
        switch self.state {
        case .idle, .error:
            self._set(state: .connecting)
            self._stream.start(withHost: host, sessionId: self.sessionId)
        case .connecting, .streaming:
            break
        }
    }

    func stopStreaming() {
        switch self.state {
        case .idle, .error:
            break
        case .connecting, .streaming:
            self._stream.cancel()
            self._set(state: .idle)
        }
    }

}
