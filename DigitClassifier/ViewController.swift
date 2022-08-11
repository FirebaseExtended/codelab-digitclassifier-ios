// Copyright 2019 The TensorFlow Authors. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import Sketch
import FirebaseAnalytics

class ViewController: UIViewController, SketchViewDelegate {

  @IBOutlet weak var resultLabel: UILabel!
  @IBOutlet weak var sketchView: SketchView!
  private var classifier: DigitClassifier?

  override func viewDidLoad() {
    super.viewDidLoad()

    // Setup sketch view.
    sketchView.lineWidth = 30
    sketchView.backgroundColor = UIColor.black
    sketchView.lineColor = UIColor.white
    sketchView.sketchViewDelegate = self

    // Download the model from Firebase
    print("Fetching model...")
    ModelLoader.fetchParameterizedModel { (customModel, error) in
      guard let customModel = customModel else {
        if let error = error {
          print(error)
        }
        return
      }

      print("Model download complete")

      // Initialize a DigitClassifier instance
      DigitClassifier.newInstance(modelPath: customModel.path) { result in
      switch result {
        case let .success(classifier):
          self.classifier = classifier
        case .error(_):
          self.resultLabel.text = "Failed to initialize."
        }
      }
    }
  }

  /// Clear drawing canvas and result text when tapping Clear button.
  @IBAction func tapClear(_ sender: Any) {
    sketchView.clear()
    resultLabel.text = "Please draw a digit."
  }

  /// Called when the user taps "Yes" under "Was this correct?"
  @IBAction func correctButtonPressed(_ sender: Any) {
    Analytics.logEvent("correct_inference", parameters: nil)
  }

  /// Callback executed every time there is a new drawing
  func drawView(_ view: SketchView, didEndDrawUsingTool tool: AnyObject) {
    classifyDrawing()
  }

  /// Classify the drawing currently on the canvas and display result.
  private func classifyDrawing() {
    guard let classifier = self.classifier else { return }

    // Capture drawing to RGB file.
    UIGraphicsBeginImageContext(sketchView.frame.size)
    sketchView.layer.render(in: UIGraphicsGetCurrentContext()!)
    let drawing = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext();

    guard drawing != nil else {
      resultLabel.text = "Invalid drawing."
      return
    }

    // Run digit classifier.
    classifier.classify(image: drawing!) { result in
      // Show the classification result on screen.
      switch result {
      case let .success((classificationResult, maxConfidence)):
        self.resultLabel.text = classificationResult
        Analytics.logEvent("digit_classification", parameters: ["confidence": maxConfidence])
      case .error(_):
        self.resultLabel.text = "Failed to classify drawing."
      }
    }
  }

}

