 import UIKit
 import PlaygroundSupport
 
 class ViewController : UIViewController {
    
    override func loadView() {
        
        let view = UIView()
        
        let stampPDFDrawView = StampPDFDrawView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        
        view.addSubview(stampPDFDrawView)
        
        self.view = view
        
        let object = DrawText(text: "★★G★R★A★T★★")
        
        object.textsLayer.frame.size = stampPDFDrawView.PDFSize
        
        object.radius = 20
        
        stampPDFDrawView.commands = [
            Command.DrawText(object)
        ]
    }
 }
 
 PlaygroundPage.current.liveView = ViewController()
 
 class StampPDFDrawView: UIView {
    
    // PDF Size(mm)
    var PDFSize = CGSize(width: mm_to_px(18.0), height: mm_to_px(18.0))
    
    var commands: [Command]! {
        didSet {
            PDFData = createPDFData(export: false)
        }
    }
    
    var PDFData: NSMutableData! {
        didSet {
            setNeedsDisplay()
        }
    }
    
    // 回転
    var angle: CGFloat = 0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = .white
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func draw(_ rect: CGRect) {
        
        guard PDFData != nil else { return }
        
        let context = UIGraphicsGetCurrentContext()!
        
        // 上下反転
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: 0, y: -rect.height)
        
        let page = CGPDFDocument(CGDataProvider(data: PDFData)!)!.page(at: 1)!
        
        let PDFRect = page.getBoxRect(.artBox)
        
        context.translateBy(x: 0, y: rect.height / 3 - rect.height * (PDFRect.height / PDFRect.width) / 3)
        
        context.scaleBy(x: rect.width / PDFRect.width, y: (rect.height / PDFRect.height) * (PDFRect.height / PDFRect.width))
        
        context.drawPDFPage(page)
    }
    
    func mapPoint(topLeft: CGPoint, imgWidth: CGFloat, imgHeight: CGFloat, point: CGPoint, type: Int = 0) -> CGPoint {
        let maxOffsetY:CGFloat = 7.0
        var newPoint:CGPoint = point
        let org = CGPoint(x: topLeft.x + imgWidth / 2, y: topLeft.y + imgHeight / 2 - 1.5)
        
        let maxDist = imgWidth / 2//sqrt(((imgWidth / 2) * (imgWidth / 2)) + ((imgHeight / 2) * (imgHeight / 2)))
        let dist = sqrt(((point.x - org.x) * (point.x - org.x)) + ((point.y - org.y) * (point.y - org.y)))
        
        
        let radius: CGFloat = sqrt((imgWidth / 2.0) * (imgWidth / 2.0) + (maxOffsetY / 2.0) * (maxOffsetY / 2.0))
        let offsetX: CGFloat = abs( topLeft.x + imgWidth / 2.0 - point.x)
        let offsetY: CGFloat =  radius - sqrt( radius * radius - offsetX * offsetX )
        
        newPoint.y = (newPoint.y - offsetY) * 0.5
        
        //        newPoint.y = newPoint.y - 0.5
        //        if type == 1 {
        //            let offsetDist = (dist / maxDist) * (dist / maxDist)
        //            let offvar = (dist - offsetDist) / dist
        //            if point.y > org.y {
        //                newPoint.x = org.x + (newPoint.x - org.x) * offvar
        //            } else {
        //                newPoint.x = org.x + (newPoint.x - org.x) * offvar
        //            }
        //            newPoint.y = org.y + (newPoint.y - org.y) * offvar
        //        }
        
        return newPoint
    }
    
    func pathInfo(path: CGPath) -> CGMutablePath {
        Swift.print("Get origin Path")
        var bezierPoints = NSMutableArray()
        path.apply(info: &bezierPoints, function: { info, element in
            guard let resultingPoints = info?.assumingMemoryBound(to: NSMutableArray.self) else {
                return
            }
            let points = element.pointee.points
            let type = element.pointee.type
            switch type {
            case .moveToPoint:
                resultingPoints.pointee.add([NSNumber(value: Double(points[0].x)), NSNumber(value: Double(points[0].y)), "moveTo"])
                Swift.print("moveTo - (\(NSNumber(value: Double(points[0].x))), \(NSNumber(value: Double(points[0].y))))")
                break
            case .addLineToPoint:
                resultingPoints.pointee.add([NSNumber(value: Double(points[0].x)), NSNumber(value: Double(points[0].y)), "lineTo"])
                Swift.print("lineTo - (\(NSNumber(value: Double(points[0].x))), \(NSNumber(value: Double(points[0].y))))")
                break
            case .addQuadCurveToPoint:
                resultingPoints.pointee.add([NSNumber(value: Double(points[0].x)), NSNumber(value: Double(points[0].y)), "qcurve"])
                resultingPoints.pointee.add([NSNumber(value: Double(points[1].x)), NSNumber(value: Double(points[1].y)), "control"])
                Swift.print("quadCurve - (\(NSNumber(value: Double(points[0].x))), \(NSNumber(value: Double(points[0].y))))")
                break
            case .addCurveToPoint:
                resultingPoints.pointee.add([NSNumber(value: Double(points[2].x)), NSNumber(value: Double(points[2].y)), "curve"])
                resultingPoints.pointee.add([NSNumber(value: Double(points[0].x)), NSNumber(value: Double(points[0].y)), "control"])
                resultingPoints.pointee.add([NSNumber(value: Double(points[1].x)), NSNumber(value: Double(points[1].y)), "control1"])
                Swift.print("curve - (\(NSNumber(value: Double(points[0].x))), \(NSNumber(value: Double(points[0].y)))) (\(NSNumber(value: Double(points[1].x))), \(NSNumber(value: Double(points[1].y)))) (\(NSNumber(value: Double(points[2].x))), \(NSNumber(value: Double(points[2].y))))")
                break
            case .closeSubpath:
                Swift.print("Path end")
                resultingPoints.pointee.add([10000, 10000, "close"])
                break
            default:
                Swift.print("path unknown")
                return
            }
        })
        let size = path.boundingBox.size
        var topLeft = CGPoint(x: 100.0, y: 100.0)
        for (_, pathElement) in bezierPoints.enumerated() {
            let element = pathElement as? NSArray
            let x = element![0] as! CGFloat
            let y = element![1] as! CGFloat
            let type: String = element![2] as! String
            if type != "close" && topLeft.x > x {
                topLeft.x = x
            }
            if type != "close" && topLeft.y > y {
                topLeft.y = y
            }
        }
        
        let resultPaths = CGMutablePath()
        
        for (index, pathElement) in bezierPoints.enumerated() {
            let element = pathElement as? NSArray
            let type: String = element![2] as! String
            var point = CGPoint(x: element![0] as! Double, y: element![1] as! Double)
            var controlPoint1, controlPoint2: CGPoint
            switch type {
            case "moveTo":
                point = mapPoint(topLeft: topLeft, imgWidth: size.width, imgHeight: size.height, point: point)
                resultPaths.move(to: point)
                break
            case "lineTo":
                let prevElement = bezierPoints[index - 1] as? NSArray
                controlPoint1 = CGPoint(x: prevElement![0] as! Double, y: prevElement![1] as! Double)
                controlPoint2 = CGPoint(x: (point.x + controlPoint1.x) / 2, y: (point.y + controlPoint1.y) / 2)
                point = mapPoint(topLeft: topLeft, imgWidth: size.width, imgHeight: size.height, point: point)
                controlPoint1 = mapPoint(topLeft: topLeft, imgWidth: size.width, imgHeight: size.height, point: controlPoint1)
                controlPoint2 = mapPoint(topLeft: topLeft, imgWidth: size.width, imgHeight: size.height, point: controlPoint2)
                resultPaths.addQuadCurve(to: point, control: controlPoint2)
                break
            case "qcurve":
                let controlElement = bezierPoints[index + 1] as? NSArray
                controlPoint1 = CGPoint(x: controlElement![0] as! Double, y: controlElement![1] as! Double)
                point = mapPoint(topLeft: topLeft, imgWidth: size.width, imgHeight: size.height, point: point)
                resultPaths.addQuadCurve(to: point, control: controlPoint1)
                break
            case "curve":
                let controlElement1 = bezierPoints[index + 1] as? NSArray
                let controlElement2 = bezierPoints[index + 2] as? NSArray
                controlPoint1 = CGPoint(x: controlElement1![0] as! Double, y: controlElement1![1] as! Double)
                controlPoint2 = CGPoint(x: controlElement2![0] as! Double, y: controlElement2![1] as! Double)
                
                controlPoint1 = mapPoint(topLeft: topLeft, imgWidth: size.width, imgHeight: size.height, point: controlPoint1)
                controlPoint2 = mapPoint(topLeft: topLeft, imgWidth: size.width, imgHeight: size.height, point: controlPoint2)
                point = mapPoint(topLeft: topLeft, imgWidth: size.width, imgHeight: size.height, point: point)
                resultPaths.addCurve(to: point, control1: controlPoint1, control2: controlPoint2)
                break
            case "close":
                let prevElement = bezierPoints[index - 1] as? NSArray
                controlPoint1 = CGPoint(x: prevElement![0] as! Double, y: prevElement![1] as! Double)
                resultPaths.closeSubpath()
                break
            case "control":
                //                Swift.print("control point")
                break
            default:
                //                Swift.print("none drawable element")
                break
            }
        }
        return resultPaths
    }
    
    // CreatePDFData
    func createPDFData(export: Bool) -> NSMutableData {
        
        let PDFData = NSMutableData()
        
        UIGraphicsBeginPDFContextToData(PDFData, CGRect(origin: .zero, size: PDFSize), nil)
        
        UIGraphicsBeginPDFPage()
        
        let context = UIGraphicsGetCurrentContext()!
        
        // 回転
        context.translateBy(x: PDFSize.width / 2, y: PDFSize.height / 2)
        context.rotate(by: angle * .pi / 180.0)
        context.translateBy(x: -PDFSize.width / 2, y: -PDFSize.height / 2)
        
        for command in commands {
            switch command {
            case let .DrawText(object):
                context.saveGState()
                
                object.textsLayer.sublayers = nil
                
                let text = object.text
                
                for i in 0..<text.count {
                    let string = String(text[text.index(text.startIndex, offsetBy: i)])
                    
                    let paths = CGMutablePath()
                    
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: object.font
                    ]
                    
                    let Run = CTLineGetGlyphRuns(CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: attributes)))
                    
                    for index in 0..<CFArrayGetCount(Run) {
                        let run = unsafeBitCast(CFArrayGetValueAtIndex(Run, index), to: CTRun.self)
                        
                        let glyph = UnsafeMutablePointer<CGGlyph>.allocate(capacity: 1)
                        
                        glyph.initialize(to: 0)
                        let runCnt = CTRunGetGlyphCount(run)
                        for i in 0..<CTRunGetGlyphCount(run) {
                            CTRunGetGlyphs(run, CFRangeMake(i, 1), glyph)
                            
                            if let path = CTFontCreatePathForGlyph(unsafeBitCast(CFDictionaryGetValue(CTRunGetAttributes(run), unsafeBitCast(kCTFontAttributeName, to: UnsafeRawPointer.self)), to: CTFont.self), glyph.pointee, nil) {
                                Swift.print("==== get path info ====")
                                let newPath:CGMutablePath = pathInfo(path :path)
                                paths.addPath(newPath)
                                
                                paths.move(to: .zero)
                            }
                        }
                        
                        glyph.deinitialize(count: 1)
                        
                        glyph.deallocate()
                    }
                    
                    let radian = CGFloat(i) * .pi * 2 / CGFloat(text.count) - .pi / 2
                    
                    let size = string.size(withAttributes: [.font: object.font])
                    
                    let textLayer = CAShapeLayer()
                    
                    let x = object.textsLayer.frame.width  / 2 + object.radius * cos(radian)
                    let y = object.textsLayer.frame.height / 2 + object.radius * sin(radian)
                    
                    textLayer.frame = CGRect(origin: CGPoint(x: x - size.width / 2, y: y - size.height / 2), size: size)
                    
                    textLayer.bounds            = paths.boundingBox
                    textLayer.path              = paths
                    textLayer.isGeometryFlipped = true
                    textLayer.lineWidth = 0.1
                    textLayer.fillColor         = object.color
                    
                    // Transform
                    var transform = CATransform3DIdentity
                    
                    // Rotate
                    transform = CATransform3DRotate(transform, radian + (.pi / 2), 0.0, 0.0, 1.0)
                    
                    textLayer.transform = transform
                    
                    object.textsLayer.addSublayer(textLayer)
                }
                
                object.textsLayer.render(in: context)
                
                context.restoreGState()
            }
        }
        
        UIGraphicsEndPDFContext()
        
        return PDFData
    }
 }
 
 enum Command {
    case DrawText(DrawText)
 }
 
 class DrawText {
    
    var textsLayer = CAShapeLayer()
    
    // 文字列
    var text = ""
    // 文字色
    var color = UIColor.black.cgColor
    // Font
    var font = UIFont(name: "HiraginoSans-W3", size: 13)!
    
    // 半径
    var radius: CGFloat!
    
    init(text: String) {
        self.text = text
    }
 }
 
 func mm_to_px(_ mm: CGFloat) -> CGFloat {
    //     return 72 / 72 * mm
    return 72 / 25.4 * mm
 }
 
 
 
