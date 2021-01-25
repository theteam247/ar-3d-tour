import UIKit
import SceneKit
import ARKit

struct ImageInfo: Codable {
    let fileName: String
    let position: [Float]
    let orientation: [Float]
    let focalLength: [Float]
    let principalPoint: [Float]
}

class ViewController: UIViewController {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var captureButton: UIButton!
    @IBOutlet weak var infoView: UIVisualEffectView!
    
    private var trackingStatus: String = ""
    private var displyLink: CADisplayLink!
    private var sessionName: String?
    private var isCapturing: Bool = false {
        didSet {
            updateUI()
        }
    }
    private var imageInfos: [ImageInfo] = []
    private weak var actionToEnable : UIAlertAction?
    
    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        UIApplication.shared.isIdleTimerDisabled = true
        sceneView.delegate = self
        sceneView.showsStatistics = true
        #if DEBUG
        sceneView.debugOptions = [.showWorldOrigin]
        #endif
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.worldAlignment = .gravity
        configuration.isAutoFocusEnabled = true
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    // MARK: - User Actions
    @IBAction func captureButtonClicked(_ sender: Any) {
        if !isCapturing {
            showSessionNameAlert()
        } else {
            stopCaputre()
        }
    }
}
// MARK: - UI
extension ViewController {
    func updateUI() {
        if !isCapturing {
            captureButton.setImage(UIImage(systemName: "play.circle"), for: .normal)
        } else {
            captureButton.setImage(UIImage(systemName: "stop.circle"), for: .normal)
        }
    }
    
    func showSessionNameAlert() {
        let alertController = UIAlertController(title: "Please name your session", message: "", preferredStyle: .alert)
        let saveAction = UIAlertAction(title: "Save", style: .default, handler: { alert -> Void in
            let textField = alertController.textFields![0] as UITextField
            if let txt = textField.text, !txt.isEmpty {
                self.sessionName = txt
                if DataManager.shared.createFolder(name: txt) {
                    self.startCapture()                    
                }
            }
        })
        saveAction.isEnabled = false
        self.actionToEnable = saveAction
        alertController.addAction(saveAction)
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alertController.addTextField(configurationHandler: {(textField : UITextField!) -> Void in
            textField.placeholder = "Session name"
            textField.addTarget(self, action: #selector(self.textChanged(sender:)), for: .editingChanged)
        })
        self.present(alertController, animated: true, completion: nil)
    }
    
    @objc func textChanged(sender: UITextField) {
        self.actionToEnable?.isEnabled = !sender.text!.isEmpty
    }
}

// MARK: - Capture logic
extension ViewController {
    func startCapture() {
        isCapturing = true
        guard displyLink == nil else {
            displyLink.add(to: RunLoop.main, forMode: .common)
            return
        }
        displyLink = CADisplayLink(target: self, selector: #selector(captureImage))
        displyLink.preferredFramesPerSecond = 1
        displyLink.add(to: RunLoop.main, forMode: .common)
    }
    
    func stopCaputre() {
        isCapturing = false
        displyLink.remove(from: RunLoop.main, forMode: .common)
        displyLink = nil
        if let folderName = self.sessionName {
            DataManager.shared.saveImageInfo(imageInfos, to: folderName)
            imageInfos = []
        }
    }
    
    @objc func captureImage() {
        guard let folderName = sessionName else { return }
        let img = sceneView.snapshot()
        let fileName = DataManager.shared.saveImage(img, to: folderName)
        if let name = fileName,
           let imgInfo = generateImageInfo(imgName: name) {
            debugPrint(imgInfo)
            imageInfos.append(imgInfo)
        }
    }
    
    func generateImageInfo(imgName: String) -> ImageInfo? {
        guard let currentFrame = sceneView.session.currentFrame else { return nil }
        
        let transform = currentFrame.camera.transform
        let position = transform.columns.3
        let positionData = [position.x, position.y, position.z]
        
        let orientation = transform.columns.2
        let orientationData = [-orientation.x, -orientation.y, -orientation.z, orientation.w]
        
        let intrinsics = currentFrame.camera.intrinsics
        let focalLengthData = [intrinsics.columns.0.x, intrinsics.columns.1.y]
        let principalPointData = [intrinsics.columns.2.x, intrinsics.columns.2.y]
               
        let imgInfo = ImageInfo(fileName: imgName,
                                position: positionData,
                                orientation: orientationData,
                                focalLength: focalLengthData,
                                principalPoint: principalPointData)
        return imgInfo
    }
}

// MARK: - ARSCNViewDelegate
extension ViewController: ARSCNViewDelegate{
    func session(_ session: ARSession,
                      cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .notAvailable:
            trackingStatus = "Tacking: Not available!"
        case .normal:
            trackingStatus = ""
        case .limited(let reason):
            switch reason {
            case .excessiveMotion:
                trackingStatus = "Tracking: Limited due to excessive motion!"
            case .insufficientFeatures:
                trackingStatus = "Tracking: Limited due to insufficient features!"
            case .initializing:
                trackingStatus = "Tracking: Initializing..."
            case .relocalizing:
                trackingStatus = "Tracking: Relocalizing..."
            @unknown default:
                trackingStatus = "Tracking: Unknown..."
            }
        }
     }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        trackingStatus = "AR Session Failure: \(error)"
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        trackingStatus = "AR Session Was Interrupted!"
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        trackingStatus = "AR Session Interruption Ended"
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            self.statusLabel.text = self.trackingStatus
            self.infoView.isHidden = self.trackingStatus.isEmpty
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        let plane = Plane(anchor: planeAnchor, in: sceneView)
        node.addChildNode(plane)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor,
            let plane = node.childNodes.first as? Plane else { return }
        
        // Update ARSCNPlaneGeometry to the anchor's new estimated shape.
        if let planeGeometry = plane.meshNode.geometry as? ARSCNPlaneGeometry {
            planeGeometry.update(from: planeAnchor.geometry)
        }

        // Update extent visualization to the anchor's new bounding rectangle.
        if let extentGeometry = plane.extentNode.geometry as? SCNPlane {
            extentGeometry.width = CGFloat(planeAnchor.extent.x)
            extentGeometry.height = CGFloat(planeAnchor.extent.z)
            plane.extentNode.simdPosition = planeAnchor.center
        }
        
        // Update the plane's classification and the text position
        if #available(iOS 12.0, *),
            let classificationNode = plane.classificationNode,
            let classificationGeometry = classificationNode.geometry as? SCNText {
            let currentClassification = planeAnchor.classification.description
            if let oldClassification = classificationGeometry.string as? String, oldClassification != currentClassification {
                classificationGeometry.string = currentClassification
                classificationNode.centerAlign()
            }
        }
        
    }
}
