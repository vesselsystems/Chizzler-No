#!/usr/bin/env swift
import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("Usage: generate_icon.swift <output.icns>\n".utf8))
    exit(64)
}

let outputURL = URL(fileURLWithPath: arguments[1])
let fileManager = FileManager.default
let workURL = outputURL.deletingLastPathComponent().appendingPathComponent("AppIcon.iconset", isDirectory: true)

try? fileManager.removeItem(at: workURL)
try fileManager.createDirectory(at: workURL, withIntermediateDirectories: true)
try fileManager.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

struct IconFile {
    let filename: String
    let pixels: CGFloat
}

let files = [
    IconFile(filename: "icon_16x16.png", pixels: 16),
    IconFile(filename: "icon_16x16@2x.png", pixels: 32),
    IconFile(filename: "icon_32x32.png", pixels: 32),
    IconFile(filename: "icon_32x32@2x.png", pixels: 64),
    IconFile(filename: "icon_128x128.png", pixels: 128),
    IconFile(filename: "icon_128x128@2x.png", pixels: 256),
    IconFile(filename: "icon_256x256.png", pixels: 256),
    IconFile(filename: "icon_256x256@2x.png", pixels: 512),
    IconFile(filename: "icon_512x512.png", pixels: 512),
    IconFile(filename: "icon_512x512@2x.png", pixels: 1024)
]

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    let bounds = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor(calibratedRed: 0.05, green: 0.07, blue: 0.08, alpha: 1).setFill()
    bounds.fill()

    let radius = size * 0.22
    let background = NSBezierPath(roundedRect: bounds.insetBy(dx: size * 0.045, dy: size * 0.045), xRadius: radius, yRadius: radius)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.07, green: 0.10, blue: 0.12, alpha: 1),
        NSColor(calibratedRed: 0.09, green: 0.16, blue: 0.18, alpha: 1)
    ])
    gradient?.draw(in: background, angle: 315)

    let ringRect = bounds.insetBy(dx: size * 0.18, dy: size * 0.18)
    let ring = NSBezierPath(ovalIn: ringRect)
    NSColor(calibratedRed: 0.11, green: 0.72, blue: 0.66, alpha: 0.18).setStroke()
    ring.lineWidth = max(2, size * 0.018)
    ring.stroke()

    let capsuleWidth = size * 0.23
    let capsuleHeight = size * 0.45
    let capsuleRect = NSRect(
        x: bounds.midX - capsuleWidth / 2,
        y: bounds.midY - capsuleHeight / 2 + size * 0.04,
        width: capsuleWidth,
        height: capsuleHeight
    )
    let mic = NSBezierPath(roundedRect: capsuleRect, xRadius: capsuleWidth / 2, yRadius: capsuleWidth / 2)
    NSColor(calibratedRed: 0.93, green: 0.98, blue: 0.95, alpha: 1).setFill()
    mic.fill()

    NSColor(calibratedRed: 0.10, green: 0.18, blue: 0.20, alpha: 0.22).setStroke()
    for offset in [-0.10, 0.02, 0.14] {
        let y = capsuleRect.midY + size * CGFloat(offset)
        let path = NSBezierPath()
        path.move(to: NSPoint(x: capsuleRect.minX + capsuleWidth * 0.23, y: y))
        path.line(to: NSPoint(x: capsuleRect.maxX - capsuleWidth * 0.23, y: y))
        path.lineWidth = max(1, size * 0.012)
        path.lineCapStyle = .round
        path.stroke()
    }

    let arcRect = NSRect(
        x: bounds.midX - size * 0.18,
        y: bounds.midY - size * 0.18,
        width: size * 0.36,
        height: size * 0.36
    )
    let arc = NSBezierPath()
    arc.appendArc(withCenter: NSPoint(x: arcRect.midX, y: arcRect.midY), radius: size * 0.18, startAngle: 205, endAngle: 335)
    NSColor(calibratedRed: 0.24, green: 0.90, blue: 0.78, alpha: 1).setStroke()
    arc.lineWidth = max(2, size * 0.035)
    arc.lineCapStyle = .round
    arc.stroke()

    let stem = NSBezierPath()
    stem.move(to: NSPoint(x: bounds.midX, y: bounds.midY - size * 0.24))
    stem.line(to: NSPoint(x: bounds.midX, y: bounds.midY - size * 0.34))
    stem.move(to: NSPoint(x: bounds.midX - size * 0.10, y: bounds.midY - size * 0.34))
    stem.line(to: NSPoint(x: bounds.midX + size * 0.10, y: bounds.midY - size * 0.34))
    stem.lineWidth = max(2, size * 0.036)
    stem.lineCapStyle = .round
    stem.stroke()

    NSColor(calibratedRed: 0.24, green: 0.90, blue: 0.78, alpha: 1).setFill()
    for index in 0..<3 {
        let width = size * CGFloat(0.035 + Double(index) * 0.012)
        let height = size * CGFloat(0.12 + Double(index) * 0.045)
        let x = bounds.midX + size * CGFloat(0.24 + Double(index) * 0.075)
        let y = bounds.midY - height / 2 + size * 0.03
        NSBezierPath(roundedRect: NSRect(x: x, y: y, width: width, height: height), xRadius: width / 2, yRadius: width / 2).fill()
    }

    return image
}

for file in files {
    let image = drawIcon(size: file.pixels)
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write(Data("Could not render \(file.filename)\n".utf8))
        exit(1)
    }
    try png.write(to: workURL.appendingPathComponent(file.filename))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", workURL.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    FileHandle.standardError.write(Data("iconutil failed\n".utf8))
    exit(process.terminationStatus)
}

try? fileManager.removeItem(at: workURL)
