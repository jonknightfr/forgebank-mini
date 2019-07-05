//
//  ViewController.swift
//


import UIKit
import SafariServices
import CoreTelephony
import LocalAuthentication
import SwiftyJSON


@available(iOS 10.0, *)
class ViewController: UIViewController, UITextFieldDelegate, SFSafariViewControllerDelegate  {

    var touchIDfails = 0
    var button: UIButton!

    
    func browserLogin() {
        let defaults = UserDefaults.standard
        let oauthURL = NSURL(string: defaults.string(forKey: "bank_host")! + "/openam/oauth2/authorize?response_type=code&scope=uid%20openid%20givenName%20sn%20mail%20postalAddress%20telephoneNumber&decision=allow&client_id="+defaults.string(forKey:"client_id")!+"&redirect_uri=forgebank://oidc_callback") as! URL
        let safariVC = SFSafariViewController(url: oauthURL)
        self.present(safariVC, animated: true, completion: nil)
        safariVC.delegate = self
    }
    

    @objc func actionLogin() {
        SessionManager.currentSession.checkAccessToken(login: false, successHandler: {
            let authorization = LAContext()
            let authPolicy = LAPolicy.deviceOwnerAuthenticationWithBiometrics
            
            var authorizationError: NSError?
            if (authorization.canEvaluatePolicy(authPolicy, error: &authorizationError)) {
                // if device is touch id capable do something here
                authorization.evaluatePolicy(authPolicy, localizedReason: "Touch the fingerprint sensor to login", reply: {(success,error) in
                    if(success){
                        let mainStoryboardIpad : UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
                        let initialViewControlleripad : UIViewController = mainStoryboardIpad.instantiateViewController(withIdentifier: "ProfileView") as UIViewController
                        DispatchQueue.main.async(execute: {
                            let app = UIApplication.shared.delegate as! AppDelegate
                            app.window = UIWindow(frame: UIScreen.main.bounds)
                            app.window?.rootViewController = initialViewControlleripad
                            app.window?.makeKeyAndVisible()
                        });
                    } else {
                        print(error!.localizedDescription)
                        DispatchQueue.main.async(execute: {
                            self.touchIDFailureAlert()
                        });
                    }
                })
            } else {
                // add alert
                print("Not Touch ID Capable")
                if UserDefaults.standard.string(forKey: "web_login") == "Web Login" { self.browserLogin() }
                else { self.RESTLogin() }
            }
        }, failureHandler: {
            if UserDefaults.standard.string(forKey: "web_login") == "Web Login" { self.browserLogin() }
            else { self.RESTLogin() }
        })
    }
 
    
    @objc func RESTsignUp() {
        authState = JSON("")
        RESTLogin(tree: "OnboardTree")
    }
    
    
    var authState:JSON = JSON("")
    var inputs:[UIView] = []
    
    func RESTLogin(tree:String = "SimpleTree") {
        let defaults = UserDefaults.standard
        
        let authnUrl = defaults.string(forKey: "bank_host")! + "/openam/json/authenticate?authIndexType=service&authIndexValue=" + tree
        print ("OpenAM URL \(authnUrl)")
        
        let tokenRequest = NSMutableURLRequest(url: URL(string: authnUrl)!)
        tokenRequest.httpMethod = "POST"
        tokenRequest.httpBody = authState.rawString(options:[])!.data(using: String.Encoding.utf8)
        tokenRequest.addValue("application/json", forHTTPHeaderField: "content-type")
        tokenRequest.addValue("Please confirm your login to ForgeBank", forHTTPHeaderField: "X-PushMessage")
        tokenRequest.addValue("protocol=1.0,resource=2.0", forHTTPHeaderField: "Accept-API-Version")
        tokenRequest.addValue("iPhone REST", forHTTPHeaderField: "User-Agent")

        print("SENDING: \(authState.rawString(options:[]))")
        
        URLSession.shared.dataTask(with: tokenRequest as URLRequest, completionHandler: {
            data, response, error in
            
            // A client-side error occured
            if error != nil {
                print("Failed to send authentication request: \(error?.localizedDescription)!")
            }
            
            let responseCode = (response as! HTTPURLResponse).statusCode
            let responseData = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)
            print("Authentication: received Response (\(responseCode)): \(responseData)")
            
            if (responseCode == 200) {
                let dataFromString = responseData!.data(using: String.Encoding.utf8.rawValue, allowLossyConversion: false)
                self.authState = try! JSON(data: dataFromString!)
                if (self.authState["tokenId"].exists()) {
                    SessionManager.currentSession.tokenId = self.authState["tokenId"].stringValue
                    print("AUTHENTICATED!")
                    SessionManager.currentSession.getOAuthGrantCode()
                } else {
                    DispatchQueue.main.async {
                        self.renderCallbacks()
                    }
                }
            } else if (responseCode == 401) {
                let dataFromString = responseData!.data(using: String.Encoding.utf8.rawValue, allowLossyConversion: false)
                let reason = try! JSON(data: dataFromString!)
                if (reason["detail"].exists()) && (reason["detail"]["failureUrl"] == "LOCKED") {
                    let alertController = UIAlertController(title: "Locked", message:
                        "Sorry, this device has been reported as retired and we have notified the owner.", preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: "Dismiss", style: .default))
                    DispatchQueue.main.async(execute: {
                        self.present(alertController, animated: true, completion: nil)
                        self.authState = JSON("")
                        self.viewDidLoad()
                    });
                } else {
                    let alertController = UIAlertController(title: "Login Failed", message:
                        "Sorry, login failed. Please try again.", preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: "Dismiss", style: .default))
                    DispatchQueue.main.async(execute: {
                        self.present(alertController, animated: true, completion: nil)
                        self.authState = JSON("")
                        self.RESTLogin()
                    });
                }
            } else {
                self.authState = JSON("")
                self.RESTLogin()
            }
        }).resume()
    }
 
    
    func addLabel(py:CGFloat, callback:JSON) -> UILabel {
        let label = UILabel()
        label.frame.origin.x = 0
        label.frame.origin.y = py+5
        label.frame.size.width = view!.bounds.size.width
        label.frame.size.height = 50
        label.textAlignment = .left
        label.textColor = UIColor.white
        label.backgroundColor = #colorLiteral(red: 0.854362011, green: 0.4875436425, blue: 0.04479524493, alpha: 1)
        label.font = UIFont(name: "FontAwesome5FreeSolid", size:28)!
        switch callback["type"] {
            case "NameCallback":
                if (callback["output"][0]["value"].stringValue.lowercased().contains("email")) {
                    label.text = "  \u{f0e0}"
                } else {
                    label.text = "  \u{f2c2}"
                }
            case "PasswordCallback":
                label.text = "  \u{f084}"
            default:
                print("Unhandled callback")
            
        }
        return label
    }
    
    
    func addText(py:CGFloat, callback:JSON) -> UITextField {
        let textInput = UITextField()
        textInput.isSecureTextEntry = (callback["type"] == "PasswordCallback")
        textInput.tintColor = #colorLiteral(red: 0.9529411793, green: 0.6862745285, blue: 0.1333333403, alpha: 1)
        textInput.frame.origin.y = py+10
        textInput.frame.size.width = view!.bounds.size.width - 200
        textInput.frame.size.height = 40
        textInput.textAlignment = .center
        textInput.textColor = UIColor.white
        textInput.backgroundColor = #colorLiteral(red: 0.854362011, green: 0.4875436425, blue: 0.04479524493, alpha: 1)
        textInput.font = UIFont(name:"Helvetica", size: 20)
        textInput.placeholder = callback["output"][0]["value"].stringValue
        let str = callback["output"][0]["value"].stringValue
        textInput.attributedPlaceholder = NSAttributedString(string:callback["output"][0]["value"].stringValue, attributes: convertToOptionalNSAttributedStringKeyDictionary([convertFromNSAttributedStringKey(NSAttributedString.Key.foregroundColor): UIColor.white]))
        textInput.center.x = view!.bounds.width / 2

        return textInput
    }
    
    
    func renderCallbacks() {
        self.button.isHidden = true
        view.subviews.forEach({
            if !($0 is UIImageView) {
                $0.removeFromSuperview()
            }
        })
        var py:CGFloat = view!.bounds.size.height - 206
        inputs.removeAll()
        if let callbacks = authState["callbacks"].array {
            for (index, callback) in callbacks.reversed().enumerated() {

                if callback["type"] == "PasswordCallback" {
                    let label = addLabel(py:py, callback:callback)
                    view.addSubview(label)
                    let textInput = addText(py:py, callback:callback)
                    view.addSubview(textInput)
                    inputs.insert(textInput, at:0)
                    py -= 53
                } else if callback["type"] == "NameCallback" {
                    let label = addLabel(py:py, callback:callback)
                    view.addSubview(label)
                    let textInput = addText(py:py, callback:callback)
                    view.addSubview(textInput)
                    inputs.insert(textInput,at:0)
                    py -= 53
                }
            }
        }
        
        // Next button - if no user interaction then just continue
        if (inputs.count == 0) { continueAuth() }
        else {
            let button = UIButton()
            button.frame.origin.x = 0
            button.frame.origin.y = view!.bounds.size.height - 140
            button.frame.size.width = view!.bounds.size.width
            button.frame.size.height = 50
            button.backgroundColor = #colorLiteral(red: 0.920394361, green: 0.6160387993, blue: 0.01928387396, alpha: 1)
            button.setTitleColor(UIColor.white, for: .normal)
            button.titleLabel!.font = UIFont(name:"Helvetica-Light", size: 16)!
            button.setTitle("Next", for: .normal)
            button.addTarget(self, action: #selector(continueAuth), for: .touchUpInside)
            view.addSubview(button)
            inputs.append(button)
        }
        
        // Join ForgeRock button
        var button = UIButton()
        button.frame.origin.x = 0
        button.frame.origin.y = view!.bounds.size.height - 80
        button.frame.size.width = view!.bounds.size.width
        button.frame.size.height = 50
        button.backgroundColor = #colorLiteral(red: 0.920394361, green: 0.6160387993, blue: 0.01928387396, alpha: 1)
        button.setTitleColor(UIColor.white, for: .normal)
        button.titleLabel!.font = UIFont(name:"Helvetica-Light", size: 16)!
        button.setTitle("Join ForgeBank", for: .normal)
        button.addTarget(self, action: #selector(RESTsignUp), for: .touchUpInside)
        view.addSubview(button)
        inputs.append(button)
        
        // Back button
        button = UIButton()
        button.frame.origin.x = 10
        button.frame.origin.y = 50
        button.frame.size.width = 20
        button.frame.size.height = 20
        button.backgroundColor = .clear
        button.setTitleColor(UIColor.white, for: .normal)
        button.titleLabel!.font = UIFont(name:"FontAwesome5FreeSolid", size: 20)
        button.setTitle("\u{f137}", for: .normal)
        button.addTarget(self, action: #selector(viewDidLoad), for: .touchUpInside)
        view.addSubview(button)
        inputs.append(button)
    }
    
    
    @objc func continueAuth() {
        var touchId = false
        
        if let callbacks = authState["callbacks"].array {
            for (index, callback) in callbacks.enumerated() {
                switch callback["type"] {
                case "NameCallback", "PasswordCallback":
                    let str = (inputs[index] as! UITextField).text!
                    authState["callbacks"][index]["input"][0]["value"] = JSON(str)
                default:
                    print("Unhandled callback")
                }
            }
        }
        if !touchId { RESTLogin() }
    }
    
    
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
    
    func touchIDFailureAlert() {
        touchIDfails += 1
        // Too many failures, revert to normal sign in
        if (touchIDfails >= 3) { SessionManager.currentSession.signout() }
        let noTouchAlert : UIAlertView = UIAlertView(title: "Touch ID failed", message: "Sorry", delegate: self, cancelButtonTitle: "Okay")
        noTouchAlert.show()
    }
    
    func touchIDSuccessAlert() {
        touchIDfails = 0
        let noTouchAlert : UIAlertView = UIAlertView(title: "Touch ID success", message: "Approved", delegate: self, cancelButtonTitle: "Okay")
        noTouchAlert.show()
    }
    
    
    func registerSettingsBundle(){
        let appDefaults = [String:AnyObject]()
        UserDefaults.standard.register(defaults: appDefaults)
    }
    
    
    @objc func keyboardWillShow(sender: NSNotification) {
        if let keyboardSize = (sender.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            let keyboardHeight = keyboardSize.height
            print(keyboardHeight)
            self.view.frame.origin.y = 0 - keyboardHeight // Move view points upward
        }
    }
    
    
    @objc func keyboardWillHide(sender: NSNotification) {
        self.view.frame.origin.y = 0 // Move view to original position
    }
    
    
    override func viewDidLoad() {
        print("ViewController: viewDidLoad")
        super.viewDidLoad()
        
        authState = JSON("")
        view.subviews.forEach({
            $0.removeFromSuperview()
        })
        inputs.removeAll()
        
        
        // Handle keyboard obsuring inputs
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(sender:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(sender:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        // Draw background gradient
        let gradient: CAGradientLayer = CAGradientLayer()
        gradient.colors = [ #colorLiteral(red: 0.7918985486, green: 0.4595604539, blue: 0.06233157963, alpha: 1).cgColor, #colorLiteral(red: 0.9875505567, green: 0.6812157035, blue: 0, alpha: 1).cgColor ]
        gradient.locations = [0.0 , 1.0]
        gradient.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradient.endPoint = CGPoint(x: 0.0, y: 1.0)
        gradient.frame = CGRect(x: 0.0, y: 0.0, width: self.view.frame.size.width, height: self.view.frame.size.height)
        self.view.layer.insertSublayer(gradient, at: 0)
        

        // Render logo
        let logoImage = UIImage(named: "ForgeBank-logo")
        let logo = UIImageView(image: logoImage)
        logo.frame.size.width = (view!.bounds.size.width * 2 / 5)
        logo.frame.size.height = logo.frame.size.width * (logoImage!.size.height / logoImage!.size.width)
        logo.center = self.view.center
        logo.center.y = 100
        logo.contentMode = UIView.ContentMode.scaleAspectFill
        self.view.addSubview(logo)

        // Render start button
        button = UIButton()
        button.frame = CGRect(x: 0, y: 0, width: 120, height: 120)
        button.center = self.view.center
        button.backgroundColor = #colorLiteral(red: 0.854362011, green: 0.4875436425, blue: 0.04479524493, alpha: 1)
        button.layer.cornerRadius = 60
        button.layer.borderColor = UIColor.white.cgColor
        button.layer.borderWidth = 3
        button.setTitleColor(UIColor.white, for: .normal)
        button.titleLabel!.font = UIFont(name:"FontAwesome5FreeSolid", size: 64)
        button.setTitle("\u{f52e}", for: .normal)
        button.addTarget(self, action: #selector(actionLogin), for: .touchUpInside)
        self.view.addSubview(button)
        
        // Version number
        let appVersion = Bundle.main.infoDictionary!["CFBundleShortVersionString"]
        var label = UILabel()
        label.textAlignment = .center
        label.textColor = .white
        label.font = UIFont(name:"Helvetica-Light", size: 14)
        label.text = "v\(appVersion ?? "")"
        label.sizeToFit()
        label.center.x = self.view.center.x
        label.center.y = logo.center.y + (logo.frame.size.height/2) + 5
        self.view.addSubview(label)

        
        label = UILabel()
        label.textAlignment = .center
        label.textColor = .white
        label.font = UIFont(name:"Helvetica-Light", size: 24)
        label.text = "Welcome to ForgeBank"
        label.frame = CGRect(x: 20, y: Int(view!.bounds.size.height-250), width: Int(view!.bounds.size.width-40), height: 200)
        label.lineBreakMode = NSLineBreakMode.byWordWrapping
        label.numberOfLines = 0
        label.center.x = self.view.center.x
        self.view.addSubview(label)
    }

    
    override func viewDidAppear(_ animated: Bool) {
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
}


// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToOptionalNSAttributedStringKeyDictionary(_ input: [String: Any]?) -> [NSAttributedString.Key: Any]? {
	guard let input = input else { return nil }
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (NSAttributedString.Key(rawValue: key), value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSAttributedStringKey(_ input: NSAttributedString.Key) -> String {
	return input.rawValue
}
