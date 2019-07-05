//
//  ProfileViewController.swift
//  ForgeBank
//
//  Created by Jon Knight on 27/12/2018.
//  Copyright © 2018 Identity Hipsters. All rights reserved.
//

import UIKit
import SafariServices
import SwiftyJSON

extension UIViewController
{
    func hideKeyboard()
    {
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(
            target: self,
            action: #selector(UIViewController.dismissKeyboard))
        
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    @objc func dismissKeyboard()
    {
        view.endEditing(true)
    }
}

extension UITextField {
    func setLeftPaddingPoints(_ amount:CGFloat){
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: self.frame.size.height))
        self.leftView = paddingView
        self.leftViewMode = .always
    }
    func setRightPaddingPoints(_ amount:CGFloat) {
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: self.frame.size.height))
        self.rightView = paddingView
        self.rightViewMode = .always
    }
}


@available(iOS 10.0, *)
class ProfileViewController: UIViewController {

    var colours = [ "blueTitle": #colorLiteral(red: 0.5209391117, green: 0.5980842113, blue: 0.8005059361, alpha: 1), "blue": #colorLiteral(red: 0.3390883803, green: 0.4074057341, blue: 0.6696556807, alpha: 1), "purpleTitle": #colorLiteral(red: 0.9981310964, green: 0.7131610513, blue: 0.7546111941, alpha: 1), "purple": #colorLiteral(red: 0.5845285058, green: 0.3933349252, blue: 0.5203692913, alpha: 1), "greenTitle": #colorLiteral(red: 0.41092664, green: 0.6300981641, blue: 0.5744281411, alpha: 1), "green": #colorLiteral(red: 0.1417149603, green: 0.3938753903, blue: 0.3735681772, alpha: 1) ]
    
    @IBOutlet weak var mScrollView: UIScrollView!
    var spinner:SpinnerView!
    var py:Int = 0
    
    var givenName = UITextField()
    var sn = UITextField()
    var mail = UITextField()
    var telephoneNumber = UITextField()
    var postalCode = UITextField()
    var postalAddress = UITextField()
    var address2 = UITextField()
    var city = UITextField()

    
    @objc func refreshView(refreshControl: UIRefreshControl?) {
        if (refreshControl != nil) { refreshControl!.endRefreshing() }
        self.view.setNeedsDisplay()
        spinner = startSpinner()
        SessionManager.currentSession.refreshAll(completionHandler: {
            DispatchQueue.main.async {
                self.stopSpinner(spinner: self.spinner)
                self.updateDisplay()
            }
        }, failureHandler: {
            self.stopSpinner(spinner: self.spinner)
            SessionManager.currentSession.signout()
            self.performSegue(withIdentifier: "ProfileToLogin", sender: self)
        })
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.updateDisplay()
        self.hideKeyboard()
        //refreshView(refreshControl: nil)
    }
    

    override func viewDidAppear(_ animated: Bool) {
        print("viewDidAppear: ProfileView")
        if (SessionManager.currentSession.refreshRequired) {
            refreshView(refreshControl: nil)
        } else {
            DispatchQueue.main.async {
                self.updateDisplay()
            }
        }
    }

    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { _ in
            self.updateDisplay()
        }
    }
    
    
    func addLabel(x:Int, y:Int, textColor: UIColor, size:Int, text:String) -> UILabel{
        let label = UILabel()
        label.frame.origin.y = CGFloat(y)
        label.frame.origin.x = CGFloat(x)
        label.frame.size.width = view!.bounds.size.width - 85
        label.textAlignment = .left
        label.textColor = textColor
        label.font = UIFont(name:"Helvetica-Light", size: CGFloat(size))
        label.text = text
        label.lineBreakMode = NSLineBreakMode.byWordWrapping
        label.numberOfLines = 0
        label.sizeToFit()
        mScrollView.addSubview(label)
        return label
    }
    
    
    func addRule(y:Int) {
        let hr = UIView()
        hr.frame = CGRect(x: 20, y: y, width: Int(view!.bounds.size.width-40), height: 1)
        hr.backgroundColor = UIColor.orange
        mScrollView.addSubview(hr)
    }
  
    
    
    
    func addText(placeHolder:String, textInput:UITextField) {
        textInput.tintColor = #colorLiteral(red: 0.9529411793, green: 0.6862745285, blue: 0.1333333403, alpha: 1)
        textInput.frame.origin.y = CGFloat(py)
        textInput.frame.origin.x = CGFloat(50)
        textInput.frame.size.width = view!.bounds.size.width - 85
        textInput.frame.size.height = 30
        textInput.clipsToBounds = true
        textInput.layer.cornerRadius = 15
        textInput.textColor = UIColor.darkGray
        textInput.backgroundColor = .white
        textInput.font = UIFont(name:"Helvetica", size: 16)
        textInput.placeholder = placeHolder
        textInput.setLeftPaddingPoints(15)
    }
    
    func addButton(buttonLabel:String, button:UIButton) {
        button.backgroundColor = .white
        button.setTitleColor(UIColor.darkGray, for: .normal)
        button.titleLabel!.font = UIFont(name:"Helvetica", size: 16)
        button.setTitle(buttonLabel, for: .normal)
        
        button.frame.origin.y = CGFloat(py)
        button.frame.origin.x = CGFloat(50)
        button.frame.size.width = 130
        button.frame.size.height = 36
        button.clipsToBounds = true
        button.layer.cornerRadius = 18
    }
        

    
    func drawInputSection(titleColor:String, color:String, title:String, labels:[String], placeHolders:[String], fields:[UIView]){
        let startpy = py
        var hr = UIView()
        hr.frame = CGRect(x: 20, y: py, width: Int(view!.bounds.size.width-40), height: 40)
        hr.layer.cornerRadius = 10
        hr.backgroundColor = colours[titleColor]
        mScrollView.addSubview(hr)
        var label = addLabel(x:35, y: py+10, textColor: .white, size:16, text: title)
        label.center.y = hr.center.y
        
        hr = UIView()
        hr.frame = CGRect(x: 35, y: py+50, width: Int(view!.bounds.size.width-55), height: 300)
        hr.layer.cornerRadius = 16
        hr.backgroundColor = colours[color]
        mScrollView.addSubview(hr)
        py += 60
        
        for i in 0...labels.count-1 {
            if (labels[i] != "") {
                let label = addLabel(x:50, y: py, textColor: .white, size:16, text: labels[i])
                py += Int(label.frame.size.height) + 8
            }
            switch fields[i] {
            case is UITextField:
                addText(placeHolder: placeHolders[i], textInput: fields[i] as! UITextField)
            default:
                print("Unexpected control")
            }
            py += 38
            mScrollView.addSubview(fields[i])
        }
        hr.frame.size.height = CGFloat(py - startpy - 40)
        py += 20
    }



    
    func updateDisplay() {
        // Delete previous content
        mScrollView.subviews.map { $0.removeFromSuperview() }
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshView(refreshControl:)), for: .valueChanged)
        mScrollView.refreshControl = refreshControl
        mScrollView.isScrollEnabled = true
        mScrollView.isUserInteractionEnabled = true
        py = 50
        
        // Title
        addLabel(x:20, y:py, textColor:UIColor.white, size:20, text:"ABOUT YOU")
        addRule(y:py + 25)
        py += 35
        
        

        givenName.text = SessionManager.currentSession.accountDetails["givenName"].stringValue
        sn.text = SessionManager.currentSession.accountDetails["sn"].stringValue
        mail.text = SessionManager.currentSession.accountDetails["mail"].stringValue
        telephoneNumber.text = SessionManager.currentSession.accountDetails["telephoneNumber"].stringValue
        postalCode.text = ""
        postalAddress.text = SessionManager.currentSession.accountDetails["postalAddress"].stringValue
        address2.text = ""
        city.text = ""
        
        drawInputSection(titleColor: "purpleTitle", color: "purple", title: "What's your name?", labels:["First Name", "Last Name"],
                    placeHolders:["First Name", "Last Name"],
                    fields:[givenName, sn])
   
        drawInputSection(titleColor: "purpleTitle", color: "purple", title: "What's your email address?", labels:["Email Address"],
                    placeHolders:["Email Address"],
                    fields:[mail])
        
        drawInputSection(titleColor: "purpleTitle", color: "purple", title: "Where do you live?", labels:["Post Code / Zip Code", "Address", "", ""],
                    placeHolders:["Post Code / Zip Code", "Address", "Address 2", "City"],
                    fields:[postalCode, postalAddress, address2, city])
   
        drawInputSection(titleColor: "purpleTitle", color: "purple", title: "What's your phone number?", labels:["Phone Number"],
                    placeHolders:["Phone Number"],
                    fields:[telephoneNumber])
        
        
   
        // Diagnostics
        addLabel(x:20, y:py, textColor:UIColor.white, size:20, text:"UNDER THE COVERS")
        addRule(y:py + 25)

        addLabel(x:20, y:py+40, textColor:UIColor.white, size:16, text:"OAuth Response")
        var label = UILabel()
        label.frame.origin.y = CGFloat(py+60)
        label.frame.origin.x = CGFloat(20)
        label.frame.size.width = view!.bounds.size.width-40
        label.textAlignment = .left
        label.textColor = UIColor.lightGray
        label.font = UIFont(name:"Helvetica-Light", size: CGFloat(12))
        label.numberOfLines = 0
        label.lineBreakMode = NSLineBreakMode.byCharWrapping
        label.text = SessionManager.currentSession.oauth.rawString() ?? ""
        label.sizeToFit()
        mScrollView.addSubview(label)
        py = py + Int(label.frame.height) + 55

        addLabel(x:20, y:py+35, textColor:UIColor.white, size:16, text:"OIDC Token")
        label = UILabel()
        label.frame.origin.y = CGFloat(py+55)
        label.frame.origin.x = CGFloat(20)
        label.frame.size.width = view!.bounds.size.width-40
        label.textAlignment = .left
        label.textColor = UIColor.lightGray
        label.font = UIFont(name:"Helvetica-Light", size: CGFloat(12))
        label.numberOfLines = 0
        label.lineBreakMode = NSLineBreakMode.byCharWrapping
        label.text = SessionManager.currentSession.idtoken.rawString() ?? ""
        label.sizeToFit()
        mScrollView.addSubview(label)
        py = py + Int(label.frame.height) + 80
    
        
        mScrollView.contentSize = CGSize(width: CGFloat(view!.bounds.size.width), height: CGFloat(py))

    }
    



}
