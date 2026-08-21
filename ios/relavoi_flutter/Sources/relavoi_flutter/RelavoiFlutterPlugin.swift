import Flutter
import CallKit

public class RelavoiFlutterPlugin: NSObject, FlutterPlugin, CXCallObserverDelegate {
    private let callObserver = CXCallObserver()
    private var isOnCall = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.relavoi/call_state", binaryMessenger: registrar.messenger())
        let instance = RelavoiFlutterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    override init() {
        super.init()
        callObserver.setDelegate(self, queue: nil)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isCallActive":
            result(isOnCall)
        case "hasPhoneStatePermission":
            result(true) // iOS doesn't need permission for CXCallObserver
        case "hasOverlayPermission":
            result(false) // iOS doesn't support overlays
        case "requestOverlayPermission":
            result(nil) // No-op on iOS
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        isOnCall = !call.hasEnded && (call.hasConnected || call.isOutgoing)
    }
}
