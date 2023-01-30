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
    public private(set) var state: State = .idle
    private let _stream = RicohLiveViewStream()
    
    deinit {
        self._stop()
    }
    
}

private extension RicohLiveView {
    
    func _start(host: String) {
        self._stream.setDelegate({ [weak self] frame, error in
            guard let self = self else { return }
            if let error = error {
                self._apply(error)
            } else if let frame = frame {
                self._apply(frame)
            } else {
                self._apply(.invalidResponse)
            }
        })
        self._stream.start(withHost: host, sessionId: self.sessionId)
    }
    
    func _stop() {
        self._stream.setDelegate(nil)
        self._stream.cancel()
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
        let nsError = error as NSError
        switch nsError.domain {
        case NSURLErrorDomain:
            switch nsError.code {
            case NSURLErrorTimedOut: fallthrough
            case NSURLErrorCannotFindHost: fallthrough
            case NSURLErrorCannotConnectToHost: fallthrough
            case NSURLErrorNotConnectedToInternet:
                self._apply(.noConnection)
            case NSURLErrorNetworkConnectionLost:
                self._apply(.connectionLost)
            default:
                self._apply(.unknown)
            }
        default:
            self._apply(.unknown)
        }
    }
    
    func _apply(_ error: Error) {
        self._set(state: .error(error))
    }
    
}

public extension RicohLiveView {
    
    func startStreaming(host: String = "192.168.1.1") {
        switch self.state {
        case .idle, .error:
            self._start(host: host)
            self._set(state: .connecting)
        case .connecting, .streaming:
            break
        }
    }

    func stopStreaming() {
        switch self.state {
        case .idle, .error:
            break
        case .connecting, .streaming:
            self._stop()
            self._set(state: .idle)
        }
    }

}
