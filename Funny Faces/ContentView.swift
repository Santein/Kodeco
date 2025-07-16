//
//  ContentView.swift
//  Funny Faces
//
//  Created by Santo Gaglione on 16/07/25.
//

import SwiftUI
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import AVFoundation

struct Photo: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.image)
    }
    
    
    public var image: Image
}


struct ContentView: View {
    
    enum Feature: String, CaseIterable, Identifiable {
        case eyes, mouth, sunglasses
        var id: Self { self }
    }
    
    @State private var image: UIImage?
    @State private var processedImage: UIImage?
    @State private var showPicker = false
    @State private var showCamera = false
    @State private var selectedFeatures: Set<Feature> = [.eyes]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if processedImage != nil || image != nil {
                    Image(uiImage: processedImage ?? image!)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 400)
                        .onTapGesture { applyFunnyFaces() }
                        .padding()
                } else {
                    Image(systemName: "photo.fill.on.rectangle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .padding(50)
                        .background(RoundedRectangle(cornerRadius: 18).fill(.thickMaterial))
                        .foregroundStyle(.gray)
                        .onTapGesture { showPicker = true }
                }
                
                HStack(spacing: 20) {
                    Group {
                        Button("Import Image") { showPicker = true }
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            Button("Use Live Camera") { showCamera = true }
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                GroupBox(label: Text("Select Features")) {
                    ForEach(Feature.allCases) { feature in
                        Toggle(isOn: Binding(
                            get: { selectedFeatures.contains(feature) },
                            set: { isSelected in
                                if isSelected {
                                    selectedFeatures.insert(feature)
                                } else {
                                    selectedFeatures.remove(feature)
                                }
                            }
                        )) {
                            Text(feature.rawValue.capitalized)
                        }
                    }
                }
                .padding()
                
                Button("Make it funny! 🎉") { applyFunnyFaces() }
                    .disabled(image == nil)
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom, 20)
            }
            .toolbar {
                if let image = image {
                    let photo = Photo(image: Image(uiImage: image))
                    ShareLink(
                        item: photo,
                        subject: Text("Cool Photo"),
                        message: Text("Check it out!"),
                        preview: SharePreview(
                            "I've never been this funnier! 🎉",
                            image: photo.image)
                    )
                }
            }
        }
        
        .sheet(isPresented: $showPicker) {
            ImagePicker(image: $image)
        }
        .sheet(isPresented: $showCamera) {
            LiveCameraView()
        }
    }
    
    func applyFunnyFaces() {
        guard let uiImage = image else { return }
        let ciImage = CIImage(image: uiImage)!
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        let request = VNDetectFaceLandmarksRequest { req, err in
            if let results = req.results as? [VNFaceObservation] {
                let size = uiImage.size
                UIGraphicsBeginImageContext(size)
                uiImage.draw(in: CGRect(origin: .zero, size: size))
                let ctx = UIGraphicsGetCurrentContext()!
                ctx.translateBy(x: 0, y: size.height)
                ctx.scaleBy(x: 1, y: -1)
                
                for face in results {
                    if let landmarks = face.landmarks {
                        if selectedFeatures.contains(Feature.eyes), let left = landmarks.leftPupil, let right = landmarks.rightPupil {
                            for eye in [left, right] {
                                if let point = eye.normalizedPoints.first {
                                  
                                    let faceOrigin = CGPoint(x: face.boundingBox.origin.x * size.width,
                                                             y: face.boundingBox.origin.y * size.height)
                                    let faceSize = CGSize(width: face.boundingBox.size.width * size.width,
                                                          height: face.boundingBox.size.height * size.height)
                                    
                                    let x = faceOrigin.x + point.x * faceSize.width
                                    let y = faceOrigin.y + point.y * faceSize.height
                                    
                                  
                                    let eyeDiameter = faceSize.width * 0.12
                                    let pupilInset = eyeDiameter * 0.25
                                    
                                    let eyeRect = CGRect(x: x - eyeDiameter / 2,
                                                         y: y - eyeDiameter / 2,
                                                         width: eyeDiameter,
                                                         height: eyeDiameter)
                                    
                                    ctx.setFillColor(UIColor.white.cgColor)
                                    ctx.fillEllipse(in: eyeRect)
                                    
                                    ctx.setFillColor(UIColor.black.cgColor)
                                    ctx.fillEllipse(in: eyeRect.insetBy(dx: pupilInset, dy: pupilInset))
                                }
                            }
                        }
                        if selectedFeatures.contains(Feature.mouth), let mouth = landmarks.outerLips?.normalizedPoints {
                            let path = UIBezierPath()
                            let transformedPoints = mouth.map { point in
                                CGPoint(
                                    x: face.boundingBox.origin.x * size.width + point.x * face.boundingBox.size.width * size.width,
                                    y: face.boundingBox.origin.y * size.height + point.y * face.boundingBox.size.height * size.height
                                )
                            }
                            if let first = transformedPoints.first {
                                path.move(to: first)
                                for pt in transformedPoints.dropFirst() {
                                    path.addLine(to: pt)
                                }
                                path.close()
                            }
                            
                            ctx.setFillColor(UIColor.red.cgColor)
                            ctx.addPath(path.cgPath)
                            ctx.fillPath()
                        }
                        if selectedFeatures.contains(Feature.sunglasses) {
                            let box = CGRect(
                                x: face.boundingBox.origin.x * size.width,
                                y: face.boundingBox.origin.y * size.height,
                                width: face.boundingBox.size.width * size.width,
                                height: face.boundingBox.size.height * size.height
                            )
                            
                           
                            let lensWidth = box.width / 3
                            let lensHeight = box.height / 4
                            let y = box.midY
                            
                            let leftLens = CGRect(x: box.minX + 10, y: y - lensHeight / 2, width: lensWidth, height: lensHeight)
                            let rightLens = CGRect(x: box.maxX - lensWidth - 10, y: y - lensHeight / 2, width: lensWidth, height: lensHeight)
                            
                           
                            ctx.setFillColor(UIColor.black.withAlphaComponent(0.8).cgColor)
                            ctx.fillEllipse(in: leftLens)
                            ctx.fillEllipse(in: rightLens)
                            
                            
                            let bridge = CGRect(x: leftLens.maxX, y: y - 5, width: rightLens.minX - leftLens.maxX, height: 10)
                            ctx.fill(bridge)
                        }
                    }
                }
                processedImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
            }
        }
        try? handler.perform([request])
    }
}


#Preview {
    ContentView()
}
