// Prints the running time a capture shows, such as 00:25: the largest text in it shaped like one, read with Vision.
// capture.sh uses it to keep an iPhone capture and a Watch capture that show the same time.
// Usage: clock <capture.png>
import Foundation
import Vision

guard CommandLine.arguments.count == 2,
    let source = CGImageSourceCreateWithURL(URL(filePath: CommandLine.arguments[1]) as CFURL, nil),
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
else {
    print("usage: clock <capture.png>")
    exit(2)
}

let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.usesLanguageCorrection = false
try VNImageRequestHandler(cgImage: image).perform([request])

// The status bar's clock has the same shape, so the time is the tallest match.
let time = (request.results ?? [])
    .compactMap { observation -> (text: String, height: CGFloat)? in
        guard let text = observation.topCandidates(1).first?.string,
            text.wholeMatch(of: #/\d{1,2}:\d{2}/#) != nil
        else { return nil }
        return (text, observation.boundingBox.height)
    }
    .max { $0.height < $1.height }
print(time?.text ?? "")
