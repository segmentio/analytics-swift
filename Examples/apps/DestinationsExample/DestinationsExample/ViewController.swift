//
//  ViewController.swift
//  DestinationsExample
//
//  Created by Brandon Sneed on 5/27/21.
//

import UIKit
import Segment
import AppsFlyerLib

enum SpecEvent: Int {
    case track
    case screen
    case group
    case identify
    case alias
    
    func eventTypeName() -> String {
        switch self {
            case .track:
                return "name"
            case .identify:
                return "user id"
            case .screen:
                return "screen title"
            case .group:
                return "group id"
            case .alias:
                return "new id"
        }
    }
}

class ViewController: UIViewController {
    
    @IBOutlet weak var propertiesStack: UIStackView?
    @IBOutlet weak var eventSegment: UISegmentedControl?
    @IBOutlet weak var propertiesLabel: UILabel?
    @IBOutlet weak var propertiesStepper: UIStepper?
    @IBOutlet weak var eventField: UITextField?
    
    var analytics: Analytics? {
        return UIApplication.shared.delegate?.analytics
    }
    
    private var keysFields = [UITextField]()
    private var propertiesFields = [UITextField]()
        
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        title = "Spec Events"
        propertiesStepper?.autorepeat = false
        propertiesStepper?.maximumValue = 6
        propertiesStepper?.addTarget(self, action: #selector(stepperChanged(_:)), for: .valueChanged)
        
        eventSegment?.addTarget(self, action: #selector(eventChoiceChanged(_:)), for: .valueChanged)
        
        propertiesStack?.spacing = 4.0
    }


    @IBAction func eventAction(_ sender: Any) {
        
        view.endEditing(true)
        
        // Determine the current segment
        guard let selectedIndex = eventSegment?.selectedSegmentIndex else {
            return
        }
        
        let specChosen = SpecEvent(rawValue: selectedIndex)
        
        switch specChosen {
            case .track:
                trackEvent()
            case .screen:
                screenEvent()
            case .group:
                groupEvent()
            case .identify:
                identifyEvent()
            case .alias:
                aliasEvent()
            case .none:
                analytics?.log(message: "Failed to establish event type")
        }
        
        clearAll()
    }
    
    func trackEvent() {
        guard let eventFieldText = eventField?.text else { return }
        analytics?.track(name: eventFieldText, properties: valuesEntered())
    }
    
    func screenEvent() {
        guard let eventFieldText = eventField?.text else { return }
        analytics?.screen(title: eventFieldText, properties: valuesEntered())
    }
    
    func groupEvent() {
        guard let eventFieldText = eventField?.text else { return }
        analytics?.group(groupId: eventFieldText, traits: valuesEntered())
    }
    
    func identifyEvent() {
        guard let eventFieldText = eventField?.text else { return }
        analytics?.identify(userId: eventFieldText, traits: valuesEntered())
    }
    
    func aliasEvent() {
        guard let eventFieldText = eventField?.text else { return }
        analytics?.alias(newId: eventFieldText)
    }
}

extension ViewController {
    
    @objc
    func stepperChanged(_ stepper: UIStepper) {
        
        let currentStepCount = Int(stepper.value)
        if propertiesFields.count < currentStepCount {
            
            let captureView = UIView()
            captureView.tag = propertiesFields.count + 100
            captureView.alpha = 0.0
            
            let nextKeyField = UITextField()
            nextKeyField.autocorrectionType = .no
            nextKeyField.autocapitalizationType = .none
            nextKeyField.placeholder = "Key..."
            nextKeyField.borderStyle = .roundedRect
            keysFields.append(nextKeyField)
            
            let nextField = UITextField()
            nextField.autocorrectionType = .no
            nextField.autocapitalizationType = .none
            nextField.placeholder = "Value..."
            nextField.borderStyle = .roundedRect
            propertiesFields.append(nextField)
            
            captureView.addSubview(nextKeyField)
            captureView.addSubview(nextField)
            
            nextKeyField.translatesAutoresizingMaskIntoConstraints = false
            nextKeyField.heightAnchor.constraint(equalToConstant: 36.0).isActive = true
            nextKeyField.leadingAnchor.constraint(equalTo: captureView.leadingAnchor).isActive = true
            
            nextField.translatesAutoresizingMaskIntoConstraints = false
            nextField.widthAnchor.constraint(equalTo: nextKeyField.widthAnchor).isActive = true
            nextField.centerYAnchor.constraint(equalTo: nextKeyField.centerYAnchor).isActive = true
            nextField.heightAnchor.constraint(equalToConstant: 36.0).isActive = true
            nextField.trailingAnchor.constraint(equalTo: captureView.trailingAnchor).isActive = true
            nextField.leadingAnchor.constraint(equalTo: nextKeyField.trailingAnchor, constant: 8.0).isActive = true
            nextField.topAnchor.constraint(equalTo: captureView.topAnchor).isActive = true
            nextField.bottomAnchor.constraint(equalTo: captureView.bottomAnchor).isActive = true
            
            propertiesStack?.addArrangedSubview(captureView)
            
            UIView.animate(withDuration: 0.3, delay: 0.0, options: .curveEaseInOut, animations: {
                captureView.alpha = 1.0
                captureView.layoutIfNeeded()
            }, completion: nil)
            
        } else {
            if propertiesFields.last != nil,
               keysFields.last != nil,
               let captureView = propertiesStack?.viewWithTag(currentStepCount + 100) {

                propertiesFields.removeLast()
                keysFields.removeLast()
                captureView.removeFromSuperview()
            }
        }
    }
    
    @objc
    func eventChoiceChanged(_ segment: UISegmentedControl) {
        
        // Dismiss the KB
        view.endEditing(true)
        
        switch segment.selectedSegmentIndex {
            case 0, // Track
                 1: // Screen
                propertiesLabel?.text = "Properties"
                propertiesStepper?.isEnabled = true
            case 2, // Group
                 3: // Identify
                propertiesLabel?.text = "Traits"
                propertiesStepper?.isEnabled = true
            case 4: // Alias
                propertiesLabel?.text = ""
                propertiesStepper?.isEnabled = false
            default:
                propertiesLabel?.text = ""
                propertiesStepper?.isEnabled = false
        }
        
        let specEvent = SpecEvent(rawValue: segment.selectedSegmentIndex)
        eventField?.placeholder = specEvent?.eventTypeName()
    }
    
    private func valuesEntered() -> [String: AnyHashable]? {
        var keyValues = [String: AnyHashable]()
        for (index, keyField) in keysFields.enumerated() {
            let valueField = propertiesFields[index]
            if let keyFieldText = keyField.text,
               let valueFieldText = valueField.text,
               !keyFieldText.isEmpty, !valueFieldText.isEmpty {
                keyValues[keyFieldText] = valueFieldText
            }
        }
        
        if keyValues.isEmpty {
            return nil
        } else {
            return keyValues
        }
    }
    
    private func clearAll() {
        eventField?.text = nil
        while propertiesFields.last != nil {
            let currentStepCount = propertiesFields.count - 1
            if let captureView = propertiesStack?.viewWithTag(currentStepCount + 100) {
                
                propertiesFields.removeLast()
                keysFields.removeLast()
                captureView.removeFromSuperview()
            }
        }
        propertiesStepper?.value = 0
    }
}
