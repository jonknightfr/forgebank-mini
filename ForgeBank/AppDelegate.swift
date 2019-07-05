//
//  AppDelegate.swift
//

import UIKit

extension String {
    func base64UrlDecode() -> Data? {
        var base64 = self
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let length = Double(base64.lengthOfBytes(using: String.Encoding.utf8))
        let requiredLength = 4 * ceil(length / 4.0)
        let paddingLength = requiredLength - length
        if paddingLength > 0 {
            let padding = "".padding(toLength: Int(paddingLength), withPad: "=", startingAt: 0)
            base64 += padding
        }
        return Data(base64Encoded: base64, options: .ignoreUnknownCharacters)
    }
}


@available(iOS 10.0, *)
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        let userDefaults = UserDefaults.standard
        if let storedValue = userDefaults.object(forKey: "bank_host") as? String {
            print("Got stored settings: \(storedValue)")
        } else {
            print("Can't find stored settings, creating defaults.")
            userDefaults.set("https://forgebank.frdpcloud.com", forKey:"bank_host")
            userDefaults.set("forgebank://oidc_callback", forKey:"redirect_uri")
            userDefaults.set("mobileapp", forKey:"client_id")
            userDefaults.set("Frdp-2010", forKey:"client_secret")
            userDefaults.set("REST Login", forKey:"web_login")
            userDefaults.set(true, forKey: "oneTouchLogin")
            userDefaults.synchronize()
         }
        
        if userDefaults.object(forKey: "UDID") == nil {
            let UUID = Foundation.UUID().uuidString
            userDefaults.set(UUID, forKey: "UDID")
            userDefaults.synchronize()
        }
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(_ application: UIApplication, handleOpen url: URL) -> Bool {
        // If the callback was for the OpenID Connect authentication, then handle the response
        let baseUrl = url.absoluteString.components(separatedBy: "?")[0]
        let defaults = UserDefaults.standard
        let app_redirect_uri = defaults.string(forKey: "redirect_uri")!

        if baseUrl.lowercased() == app_redirect_uri.lowercased() {
            
            // Close the SFSafariViewController
            window!.rootViewController?.presentedViewController?.dismiss(animated: true , completion: nil)
            
            var returnDictionary = [String: String]()
            let queryParams = url.absoluteString.components(separatedBy: "?")[1]
            for queryParam in (queryParams.components(separatedBy: "&")) {
                //print("Parsing query parameter: \(queryParam)")
                var queryElement = queryParam.components(separatedBy: "=")
                returnDictionary[queryElement[0]] = queryElement[1]
            }
            if (returnDictionary["code"] != nil) {
                //print("CODE: " + returnDictionary["code"]!)
                SessionManager.currentSession.getAccessToken(returnDictionary["code"]!, completionHandler: gotAccessToken)
            }
        }
        return true
    }

    
    func gotAccessToken() {
       DispatchQueue.main.async(execute: {
            let storyboard : UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
            let initialViewController : UIViewController = storyboard.instantiateViewController(withIdentifier: "ProfileView") as UIViewController
            self.window = UIWindow(frame: UIScreen.main.bounds)
            self.window?.rootViewController = initialViewController
            self.window?.makeKeyAndVisible()
        });
    }



}

