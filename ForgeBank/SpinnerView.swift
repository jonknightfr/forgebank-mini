//
//  SpinnerView.swift
//  ForgeBank
//
//  Created by Jon Knight on 07/01/2019.
//  Copyright © 2019 Identity Hipsters. All rights reserved.
//

import UIKit

extension UIViewController {
    
    func startSpinner() -> SpinnerView {
        let spinner = SpinnerView()
        addChild(spinner)
        spinner.view.frame = view.frame
        view.addSubview(spinner.view)
        spinner.didMove(toParent: self)
        return spinner
    }
    
    func stopSpinner(spinner:SpinnerView) {
        DispatchQueue.main.async(execute: {
            spinner.willMove(toParent: nil)
            spinner.view.removeFromSuperview()
            spinner.removeFromParent()
        });
    }
}


class SpinnerView: UIViewController {
    var spinner = UIActivityIndicatorView(style: .whiteLarge)
    
    override func loadView() {
        view = UIView()
        view.backgroundColor = UIColor(white: 0, alpha: 0.7)
        
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        view.addSubview(spinner)
        
        spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
    }
}
