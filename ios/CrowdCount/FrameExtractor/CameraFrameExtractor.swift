//
//  CameraFrameExtractor.swift
//  CrowdCount
//
//  Created by Dimitri Roche on 7/21/18.
//  Inspired by https://medium.com/ios-os-x-development/ios-camera-frames-extraction-d2c0f80ed05a
//

import UIKit
import AVFoundation
import RxSwift

class CameraFrameExtractor: NSObject, FrameExtractor, AVCaptureVideoDataOutputSampleBufferDelegate {
    var orientation: AVCaptureVideoOrientation = AVCaptureVideoOrientation.portrait
    var frames: Observable<UIImage> {
        return subject
    }
    var isEnabled: Bool {
        get { return connection?.isEnabled == true }
        set(isEnabled) { connection?.isEnabled = isEnabled }
    }

    private let subject = PublishSubject<UIImage>()
    private let position = AVCaptureDevice.Position.back
    private let quality = AVCaptureSession.Preset.hd1280x720

    private var permissionGranted = false
    private let captureSession = AVCaptureSession()
    private var connection: AVCaptureConnection?

    private let sessionQueue = DispatchQueue(label: "CameraFrameExtractor session queue")
    private let sampleBufferCallbackQueue = DispatchQueue(label: "CameraFrameExtractor sample buffer")

    override init() {
        super.init()
        checkPermission()
        sessionQueue.async { [unowned self] in
            self.configureSession()
            self.captureSession.startRunning()
        }
    }

    convenience init(orientation: AVCaptureVideoOrientation) {
        self.init()
        self.orientation = orientation
    }

    // MARK: AVSession configuration
    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            requestPermission()
        default:
            permissionGranted = false
        }
    }

    private func requestPermission() {
        sessionQueue.suspend()
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { [unowned self] granted in
            self.permissionGranted = granted
            self.sessionQueue.resume()
        }
    }

    private func configureSession() {
        guard permissionGranted else { return }
        captureSession.sessionPreset = quality
        guard let captureDevice = selectCaptureDevice() else { return }
        guard let captureDeviceInput = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        guard captureSession.canAddInput(captureDeviceInput) else { return }
        captureSession.addInput(captureDeviceInput)

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: sampleBufferCallbackQueue)
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable: kCVPixelFormatType_32BGRA] as? [String: Any]

        guard captureSession.canAddOutput(videoOutput) else { return }
        captureSession.addOutput(videoOutput)

        guard let connection = videoOutput.connection(with: AVFoundation.AVMediaType.video) else { return }
        guard connection.isVideoOrientationSupported else { return }
        guard connection.isVideoMirroringSupported else { return }
        connection.videoOrientation = orientation
        connection.isVideoMirrored = position == .front
        self.connection = connection
    }

    private func selectCaptureDevice() -> AVCaptureDevice? {
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: position)
    }

    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        connection.videoOrientation = orientation
        guard let uiImage = imageFromSampleBuffer(sampleBuffer: sampleBuffer) else { return }
        subject.onNext(uiImage)
    }

    // MARK: Sample buffer to UIImage conversion
    private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo: CGBitmapInfo = [.byteOrder32Little, CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)]

        guard let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else {
            return nil
        }
        guard let cgImage = context.makeImage() else { return nil }
        let image = UIImage(cgImage: cgImage)
        return image
    }
}
