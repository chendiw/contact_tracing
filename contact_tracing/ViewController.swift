//
//  ViewController.swift
//  ble_test
//
//  Created by Jiani Wang on 2022/4/22.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController {
    var myTAClient: TAClient!
    
    func startTAClient() {
        self.myTAClient.prepStartTest()
//        self.myTAClient.prepGetResult()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
//        self.myTAClient = TAClient()
        
        TokenController.didFinishLaunching()
//        TokenController.startFresh()  // delete previous file
//        TokenController.start()
        self.myTAClient = TAClient()
        startTAClient()
    }
}
