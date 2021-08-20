//
//  LoginViewController.swift
//  SegmentExtensionsExample
//
//  Created by Alan Charles on 8/10/21.
//

import UIKit
import AuthenticationServices

class LoginViewController: UIViewController {
    
    var analytics = UIApplication.shared.delegate?.analytics
    
    @IBOutlet weak var loginProviderStackView: UIStackView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupProviderLoginView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        performExistingAccountSetupFlows()
    }
    
    //appleId button
    func setupProviderLoginView() {
        let authorizationButton = ASAuthorizationAppleIDButton()
        authorizationButton.addTarget(self, action: #selector(handleAuthorizationAppleIDButtonPress), for: .touchUpInside)
        self.loginProviderStackView.addArrangedSubview(authorizationButton)
    }
    
    //prompts the user if existing login info is found.
    func performExistingAccountSetupFlows() {
        
        //prepare requests for Apple ID and password providers
        let requests = [ASAuthorizationAppleIDProvider().createRequest(),
                        ASAuthorizationPasswordProvider().createRequest()]
        
        //create and authorization controller with above requests
        let authorizationController = ASAuthorizationController(authorizationRequests: requests)
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    //perform appleId request
    @objc
    func handleAuthorizationAppleIDButtonPress() {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
        
        analytics?.track(name: "Apple ID Button Pressed")
    }
}

//MARK: - ASAuthorizationController Delegate conformance
extension LoginViewController: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        switch authorization.credential {
        case let appleIDCredential as ASAuthorizationAppleIDCredential:
            
            //struct for identify (better place to put this?)
            struct UserTraits: Codable {
                let name: PersonNameComponents?
                let email: String?
                var username: String? = nil
            }
            
            let userIdentifier = appleIDCredential.user
            let fullName = appleIDCredential.fullName
            let email = appleIDCredential.email
            
            self.saveUserInKeychain(userIdentifier)
            
            //identify the user
            analytics?.identify(userId: userIdentifier, traits: UserTraits(name: fullName, email:  email))
            
            self.showResultViewController(userIdentifier: userIdentifier, fullName: fullName, email: email)
            
        case let passwordCredential as ASPasswordCredential:
            
            let username = passwordCredential.user
            let password = passwordCredential.password
            
            DispatchQueue.main.async {
                self.showPasswordCredentialAlert(username: username, password: password)
            }
            
        default:
            break
        }
    }
    
    private func saveUserInKeychain(_ userIdentifier: String) {
        
        //change 'co.alancharles.SegmentExtensionsExample' to your identifier
        do {
            try KeychainItem(service: "co.alancharles.SegmentExtensionsExample", account: "userIdentifier").saveItem(userIdentifier)
            analytics?.track(name: "Saved to Keychain")
        } catch {
            //handle error and optionally track it
            analytics?.log(message: "Unable to save userId to keychain.", kind: .error)
        }
    }
    
    private func showResultViewController(userIdentifier: String, fullName: PersonNameComponents?, email: String?){
        guard let viewController = self.presentingViewController as? ResultViewController
        else { return }
        
        DispatchQueue.main.async {
            viewController.userIdentifierLabel.text = userIdentifier
            if let givenName = fullName?.givenName {
                viewController.givenNameLabel.text = givenName
            }
            if let familyName = fullName?.familyName {
                viewController.familyNameLabel.text = familyName
            }
            if let email = email {
                viewController.emailLabel.text = email
            }
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    private func showPasswordCredentialAlert(username: String, password: String) {
        let message = "This app has recieved your selected credential from the keychain.\n\n Username: \(username)\n Password: \(password)"
        let alertController = UIAlertController(title: "Keychain Credential Received", message: message, preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        //handle error
        analytics?.log(message: error, king: .error)
    }
}

//MARK: - ASAuthorizationController Delegate presentation conformance
extension LoginViewController: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return self.view.window!
    }
}

extension UIViewController {
    
    func showLoginViewController() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let loginViewController = storyboard.instantiateViewController(identifier: "loginViewController")
            as? LoginViewController {
            loginViewController.modalPresentationStyle = .formSheet
            loginViewController.isModalInPresentation = true
            self.present(loginViewController, animated: true, completion: nil)
        }
    }
}
