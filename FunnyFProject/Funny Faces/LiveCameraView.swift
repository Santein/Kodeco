//
//  LiveCameraView.swift
//  Funny Faces
//
//  Created by Santo Gaglione on 16/07/25.
//


import SwiftUI
import Vision
import PhotosUI

struct LiveCameraView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CameraViewController {
        CameraViewController()
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    let previewLayer = AVCaptureVideoPreviewLayer()
    let overlayLayer = CALayer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
        overlayLayer.frame = view.bounds
    }
    
    func setupCamera() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        
        session.beginConfiguration()
        session.sessionPreset = .medium
        session.addInput(input)
        
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        output.alwaysDiscardsLateVideoFrames = true
        
        if let connection = output.connection(with: .video) {
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
        }
        
        session.addOutput(output)
        session.commitConfiguration()
        
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        
        overlayLayer.frame = view.bounds
        view.layer.addSublayer(overlayLayer)
        
        session.startRunning()
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .leftMirrored, options: [:])
        let request = VNDetectFaceLandmarksRequest { req, _ in
            guard let results = req.results as? [VNFaceObservation] else { return }
            
            DispatchQueue.main.async {
                self.overlayLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
                self.drawFaceOverlays(faces: results)
            }
        }
        try? handler.perform([request])
    }
    
    func drawFaceOverlays(faces: [VNFaceObservation]) {
        let viewWidth = view.bounds.width
        let viewHeight = view.bounds.height
        
        for face in faces {
            guard let landmarks = face.landmarks else { continue }
            
            
            let boundingBox = face.boundingBox
            let faceRect = CGRect(
                x: boundingBox.origin.x * viewWidth,
                y: (1 - boundingBox.origin.y - boundingBox.height) * viewHeight,
                width: boundingBox.width * viewWidth,
                height: boundingBox.height * viewHeight
            )
            
            func convertPoint(_ normalizedPoint: CGPoint, relativeTo faceRect: CGRect) -> CGPoint {
                let x = faceRect.origin.x + normalizedPoint.x * faceRect.width
                let y = faceRect.origin.y + (1 - normalizedPoint.y) * faceRect.height
                return CGPoint(x: x, y: y)
            }
            
            drawGooglyEyes(landmarks: landmarks, faceRect: faceRect, convertPoint: convertPoint)
            
            drawSunglasses(faceRect: faceRect)
            
            drawMouthDots(landmarks: landmarks, faceRect: faceRect, convertPoint: convertPoint)
        }
    }
    
    func drawGooglyEyes(landmarks: VNFaceLandmarks2D, faceRect: CGRect, convertPoint: (CGPoint, CGRect) -> CGPoint) {
        if let leftEye = landmarks.leftEye?.normalizedPoints {
            let eyeCenter = calculateEyeCenter(eyePoints: leftEye)
            let center = convertPoint(eyeCenter, faceRect)
            drawGooglyEye(at: center, size: faceRect.height * 0.08)
        }
        
        if let rightEye = landmarks.rightEye?.normalizedPoints {
            let eyeCenter = calculateEyeCenter(eyePoints: rightEye)
            let center = convertPoint(eyeCenter, faceRect)
            drawGooglyEye(at: center, size: faceRect.height * 0.08)
        }
    }
    
    func calculateEyeCenter(eyePoints: [CGPoint]) -> CGPoint {
        let sumX = eyePoints.reduce(0) { $0 + $1.x }
        let sumY = eyePoints.reduce(0) { $0 + $1.y }
        return CGPoint(x: sumX / CGFloat(eyePoints.count), y: sumY / CGFloat(eyePoints.count))
    }
    
    func drawGooglyEye(at center: CGPoint, size: CGFloat) {
        let whiteEye = CAShapeLayer()
        let whiteRect = CGRect(x: center.x - size, y: center.y - size, width: size * 2, height: size * 2)
        whiteEye.path = UIBezierPath(ovalIn: whiteRect).cgPath
        whiteEye.fillColor = UIColor.white.cgColor
        whiteEye.strokeColor = UIColor.black.cgColor
        whiteEye.lineWidth = 1
        
        let pupil = CAShapeLayer()
        let pupilSize = size * 0.6
        let pupilRect = CGRect(x: center.x - pupilSize/2, y: center.y - pupilSize/2, width: pupilSize, height: pupilSize)
        pupil.path = UIBezierPath(ovalIn: pupilRect).cgPath
        pupil.fillColor = UIColor.black.cgColor
        
        overlayLayer.addSublayer(whiteEye)
        overlayLayer.addSublayer(pupil)
    }
    
    func drawSunglasses(faceRect: CGRect) {
        let eyeWidth = faceRect.width * 0.3
        let eyeHeight = faceRect.height * 0.15
        let frameThickness: CGFloat = 3
        
        let leftLensRect = CGRect(
            x: faceRect.minX + faceRect.width * 0.15,
            y: faceRect.minY + faceRect.height * 0.35,
            width: eyeWidth,
            height: eyeHeight
        )
        
        let rightLensRect = CGRect(
            x: faceRect.maxX - faceRect.width * 0.45,
            y: faceRect.minY + faceRect.height * 0.35,
            width: eyeWidth,
            height: eyeHeight
        )
        
        let leftLens = CAShapeLayer()
        leftLens.path = UIBezierPath(ovalIn: leftLensRect).cgPath
        leftLens.fillColor = UIColor.black.withAlphaComponent(0.8).cgColor
        leftLens.strokeColor = UIColor.black.cgColor
        leftLens.lineWidth = frameThickness
        
        let rightLens = CAShapeLayer()
        rightLens.path = UIBezierPath(ovalIn: rightLensRect).cgPath
        rightLens.fillColor = UIColor.black.withAlphaComponent(0.8).cgColor
        rightLens.strokeColor = UIColor.black.cgColor
        rightLens.lineWidth = frameThickness
        
        let bridgeRect = CGRect(
            x: leftLensRect.maxX,
            y: leftLensRect.midY - frameThickness/2,
            width: rightLensRect.minX - leftLensRect.maxX,
            height: frameThickness
        )
        let bridge = CAShapeLayer()
        bridge.path = UIBezierPath(roundedRect: bridgeRect, cornerRadius: frameThickness/2).cgPath
        bridge.fillColor = UIColor.black.cgColor
        
        overlayLayer.addSublayer(leftLens)
        overlayLayer.addSublayer(rightLens)
        overlayLayer.addSublayer(bridge)
    }
    
    func drawMouthDots(landmarks: VNFaceLandmarks2D, faceRect: CGRect, convertPoint: (CGPoint, CGRect) -> CGPoint) {
        if let outerLips = landmarks.outerLips?.normalizedPoints, outerLips.count > 2 {
            let mouthPath = UIBezierPath()
            
            let lipPoints = outerLips.map { convertPoint($0, faceRect) }
            
            mouthPath.move(to: lipPoints[0])
            
            for i in 1..<lipPoints.count {
                mouthPath.addLine(to: lipPoints[i])
            }
            
            mouthPath.close()
            
            let filledMouth = CAShapeLayer()
            filledMouth.path = mouthPath.cgPath
            filledMouth.fillColor = UIColor.red.withAlphaComponent(0.6).cgColor
            filledMouth.strokeColor = UIColor.red.cgColor
            filledMouth.lineWidth = 2
            
            overlayLayer.addSublayer(filledMouth)
        }
    }
}