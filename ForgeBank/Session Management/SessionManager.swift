//
//  SessionManager.swift
//

import Foundation
import CoreLocation
import SafariServices
import SwiftyJSON

// Helper utility to maintain a user "session" inside the application. This is for demo purposes only (best practise would be to store the tokens in the keychain etc)


@available(iOS 10.0, *)
class SessionManager {
    
    var tokenId:String = ""
    var access_token:String = ""
    var accountDetails:JSON = JSON("")
    var oauth:JSON = JSON("")
    var idtoken:JSON = JSON("")
    var oauthApps:JSON = JSON("")
    var refreshRequired:Bool = true

        
    // Singleton to store the "current" session
    static let currentSession = SessionManager()

    func signout() {
        tokenId = ""
        access_token = ""
        accountDetails = JSON ("")


        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "oauth")
        defaults.synchronize()
        
        let storage = HTTPCookieStorage.shared
        for cookie in storage.cookies! {
            storage.deleteCookie(cookie)
        }
    }
    

    func getAccessToken(_ code:String, completionHandler:@escaping ()->Void) {
        let defaults = UserDefaults.standard
        let authnUrl = defaults.string(forKey: "bank_host")! + "/openam/oauth2/access_token"
        
        let tokenRequest = NSMutableURLRequest(url: URL(string: authnUrl)!)
        tokenRequest.httpMethod = "POST"
        tokenRequest.httpBody = ("grant_type=authorization_code&redirect_uri="+defaults.string(forKey: "redirect_uri")!+"&code=\(code)").data(using: String.Encoding.utf8)
        tokenRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "content-type")

        let PasswordString = defaults.string(forKey: "client_id")! + ":" + defaults.string(forKey: "client_secret")!
        let PasswordData = PasswordString.data(using: String.Encoding.utf8)
        let base64EncodedCredential = PasswordData!.base64EncodedString(options: NSData.Base64EncodingOptions.lineLength64Characters)
        
        tokenRequest.addValue("Basic \(base64EncodedCredential)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: tokenRequest as URLRequest, completionHandler: {
            data, response, error in
            
            // A client-side error occured
            if error != nil {
                print("Failed to send authentication request: \(String(describing: error?.localizedDescription))!")
            }
            
            let responseCode = (response as! HTTPURLResponse).statusCode
            let responseData = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)
            //print("Authentication: received Response (\(responseCode)): \(String(describing: responseData))")
            
            if (responseCode == 200) {
                let dataFromString = responseData!.data(using: String.Encoding.utf8.rawValue, allowLossyConversion: false)
                var json = try! JSON(data: dataFromString!)
                if (json["access_token"].exists()) {
                    
                    let idtoken = json["id_token"]
                    let decodedIdToken = idtoken.stringValue.components(separatedBy: ".")[1].base64UrlDecode()
                    //let decode = decodedIdToken.base64UrlDecode()
                    let idtokenJson = JSON.init(parseJSON: (String(data: decodedIdToken!, encoding: String.Encoding.utf8) as String!)!)
                    
                    // Store access and refresh token away for future invocations
                    print("OAUTH Token: \(json.rawString())")
                    defaults.set(json.rawString(), forKey: "oauth")
                    defaults.synchronize()
                    SessionManager.currentSession.idtoken = JSON(idtokenJson)
                    let date = Calendar.current.date(byAdding: .second, value: json["expires_in"].int!, to: Date())
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "HH:mm:ss, dd/mm/yyyy"
                    json["expires_at"] = JSON(dateFormatter.string(from: date!))
                    SessionManager.currentSession.oauth = json

                    completionHandler()
                }
            }
        }).resume()
    }
    
    
    func refreshAccessToken(successHandler: @escaping ()->Void, failureHandler: @escaping ()->Void) {
        let defaults = UserDefaults.standard
        let stored_token = defaults.string(forKey: "oauth")

        var oauthDecoded = JSON.init(parseJSON: stored_token!)
        let refresh_token = oauthDecoded["refresh_token"].stringValue
        let authnUrl = defaults.string(forKey: "bank_host")! + "/openam/oauth2/access_token"
        print("authnUrl: \(authnUrl)")
        
        let tokenRequest = NSMutableURLRequest(url: URL(string: authnUrl)!)
        tokenRequest.httpMethod = "POST"
        tokenRequest.httpBody = ("grant_type=refresh_token&refresh_token="+refresh_token).data(using: String.Encoding.utf8)
        tokenRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "content-type")
        
        let PasswordString = defaults.string(forKey: "client_id")! + ":" + defaults.string(forKey: "client_secret")!
        let PasswordData = PasswordString.data(using: String.Encoding.utf8)
        let base64EncodedCredential = PasswordData!.base64EncodedString(options: NSData.Base64EncodingOptions.lineLength64Characters)
        tokenRequest.addValue("Basic \(base64EncodedCredential)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: tokenRequest as URLRequest, completionHandler: {
            data, response, error in
                
            // A client-side error occured
            if error != nil {
                print("Failed to send authentication request: \(String(describing: error?.localizedDescription))!")
            }
            
            let responseCode = (response as! HTTPURLResponse).statusCode
            let responseData = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)
            //print("Authentication: received Response (\(responseCode)): \(String(describing: responseData))")
            
            if (responseCode == 200) {
                let dataFromString = responseData!.data(using: String.Encoding.utf8.rawValue, allowLossyConversion: false)
                var json = try! JSON(data: dataFromString!)
                
                let idtoken = json["id_token"]
                let decodedIdToken = idtoken.stringValue.components(separatedBy: ".")[1].base64UrlDecode()
                let idtokenJson = JSON.init(parseJSON: (String(data: decodedIdToken!, encoding: String.Encoding.utf8) as String!)!)
                
                // Store access and refresh token away for future invocations
                print("OAUTH Token: \(json.rawString())")
                defaults.set(json.rawString(), forKey: "oauth")
                defaults.synchronize()
                SessionManager.currentSession.idtoken = JSON(idtokenJson)
                let date = Calendar.current.date(byAdding: .second, value: json["expires_in"].int!, to: Date())
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "HH:mm:ss, dd/mm/yyyy"
                json["expires_at"] = JSON(dateFormatter.string(from: date!))
                SessionManager.currentSession.oauth = json

                successHandler()
            } else {
                failureHandler()
            }
        }).resume()
    }
    
    
    func checkAccessToken(login: Bool, successHandler: @escaping ()->Void, failureHandler: @escaping ()->Void) {
        let defaults = UserDefaults.standard
        let stored_token = defaults.string(forKey: "oauth")
        // If we have a stored token, and (it's an API request or oneTouchLogin), then validate OAuth token
        if (stored_token != nil) && (!login || defaults.bool(forKey: "oneTouchLogin")) {
            var oauthDecoded = JSON.init(parseJSON: stored_token!)
            let access_token = oauthDecoded["access_token"].stringValue
            let authnUrl = defaults.string(forKey: "bank_host")! + "/openam/oauth2/tokeninfo"
            print("authnUrl: \(authnUrl)")
            
            let tokenRequest = NSMutableURLRequest(url: URL(string: authnUrl)!)
            tokenRequest.httpMethod = "GET"
            tokenRequest.addValue("Bearer \(access_token)", forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: tokenRequest as URLRequest, completionHandler: {
                data, response, error in
                
                // A client-side error occured
                if error != nil {
                    print("Failed to send authentication request: \(String(describing: error?.localizedDescription))!")
                }
                
                let responseCode = (response as! HTTPURLResponse).statusCode
                let responseData = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)
                print("Authentication: received Response (\(responseCode)): \(String(describing: responseData))")
                
                if (responseCode == 200) {
                    let dataFromString = responseData!.data(using: String.Encoding.utf8.rawValue, allowLossyConversion: false)
                    let json = try! JSON(data: dataFromString!)
                    // If access token is valid for at least 5 mins
                    if (json["expires_in"].doubleValue > 300) {
                        let date = Calendar.current.date(byAdding: .second, value: oauthDecoded["expires_in"].int!, to: Date())
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "HH:mm:ss, dd/mm/yyyy"
                        oauthDecoded["expires_at"] = JSON(dateFormatter.string(from: date!))
                        SessionManager.currentSession.oauth = oauthDecoded
                        SessionManager.currentSession.accountDetails = json
                        let idtoken = oauthDecoded["id_token"]
                        let decodedIdToken = idtoken.stringValue.components(separatedBy: ".")[1]
                        let decode = decodedIdToken.base64UrlDecode()
                        let json2 = JSON.init(parseJSON: (String(data: decode!, encoding: String.Encoding.utf8) as String!)!)
                        SessionManager.currentSession.idtoken = json2
                        successHandler()
                    } else {
                        self.refreshAccessToken(successHandler: successHandler, failureHandler: failureHandler)
                    }
                } else { self.refreshAccessToken(successHandler: successHandler, failureHandler: failureHandler) }
            }).resume()
        }    else {
            failureHandler()
        }
    }
    
    
    func refreshAll(completionHandler: @escaping ()->Void, failureHandler: @escaping ()->Void){
        print("Refreshing all data")
        SessionManager.currentSession.refreshRequired = false
        checkAccessToken(login: false, successHandler: { completionHandler() }, failureHandler: { failureHandler() })
    }
    
    
    // For REST authentication
    func getOAuthGrantCode() {
        let defaults = UserDefaults.standard
        
        let oauthURL = defaults.string(forKey: "bank_host")! + "/openam/oauth2/authorize?response_type=code&scope=uid%20openid%20givenName%20mail%20sn%20postalAddress%20telephoneNumber&decision=allow&client_id="+defaults.string(forKey:"client_id")!+"&redirect_uri=forgebank://oidc_callback"
        
        let tokenRequest = NSMutableURLRequest(url: URL(string: oauthURL)!)
        tokenRequest.httpMethod = "GET"
        tokenRequest.addValue("iPlanetDirectoryPro="+SessionManager.currentSession.tokenId, forHTTPHeaderField: "Cookie")
        print("Cookie: \(SessionManager.currentSession.tokenId)")
        
        MySession.getDataFromServerWithSuccess(tokenRequest) {(data) -> Void in
            print("Data: \(data)")
            var returnDictionary = [String: String]()
            let queryParams = data?.components(separatedBy: "?")[1]
            for queryParam in (queryParams?.components(separatedBy: "&"))! {
                print("Parsing query parameter: \(queryParam)")
                var queryElement = queryParam.components(separatedBy: "=")
                returnDictionary[queryElement[0]] = queryElement[1]
            }
            if (!(returnDictionary["code"] != nil)) { return; }
            
            print("Code = " + returnDictionary["code"]!)
            DispatchQueue.main.async(execute: {
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                self.getAccessToken(returnDictionary["code"]!, completionHandler: appDelegate.gotAccessToken)
            });
        }
    }
    
    // Needed to prevent NSURLSession handling the OAuth redirect (302)
    class MySession: NSObject, URLSessionDelegate {
        
        fileprivate struct SubStruct { static var result: String = "" }
        
        func URLSession(_ session: Foundation.URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: (URLRequest!) -> Void) {
            print("URLSession: \(request.url?.absoluteString)")
            SubStruct.result = (request.url?.absoluteString)!
            completionHandler(nil)
        }
        
        class func getDataFromServerWithSuccess(_ myURL: NSMutableURLRequest, success: @escaping (_ response: String?) -> Void) {
            let myDelegate: MySession? = MySession()
            let session = Foundation.URLSession(configuration: URLSessionConfiguration.default, delegate: myDelegate, delegateQueue: nil)
            
            let loadDataTask = session.dataTask(with: myURL.url!, completionHandler: { (data, response, error) -> Void in
                // OMITTING ERROR CHECKING FOR BREVITY
                success(SubStruct.result)
            })
            loadDataTask.resume()
        }
    }
    
}
