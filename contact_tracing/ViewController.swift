//
//  ViewController.swift
//  ble_test
//
//  Created by Jiani Wang on 2022/4/22.
//

import UIKit
import CoreBluetooth

//class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
//    var centralManager: CBCentralManager!  // ! means this is an unwrapped optional variable and if we refer to it later we can check for null-safety.
//    var myPeripheral: CBPeripheral!
//
//    func centralManagerDidUpdateState(_ central: CBCentralManager) {  // need to rewrite this fuction.
//        if central.state == CBManagerState.poweredOn {
//            print("BLE powered on") // Turned on
//            central.scanForPeripherals(withServices: nil, options: nil)
//        }
//        else {
//            print("Something wrong with BLE")
//            // Not on, but can have different issues
//        }
//    }
//
//    // rewrite some function: didDiscover delegate method
//    // This function is to define the behavior that find a peripheral
//    // Identify our peripheral by name, UUID, manufacturer ID, or basically anything that is part of the advertisement data
//    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
//        if let pname = peripheral.name {
//            if pname == "Jiani's" {
//                self.centralManager.stopScan()
//
//                self.myPeripheral = peripheral
//                self.myPeripheral.delegate = self
//
//                self.centralManager.connect(peripheral, options: nil)
//            }
//        }
//    }
//
//    // Once the connection is establishd, call this method.
//    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
//        self.myPeripheral.discoverServices(nil)  // ask peripheral to provide information about service
//    }
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        // Do any additional setup after loading the view.
//        centralManager = CBCentralManager(delegate: self, queue: nil)
//    }
//
//}


class ViewController: UIViewController {
    private var start: Bool = false
    private var level: String = "low level"
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        print("Start Bluetooth")
        
        // Get today's level here: Write the riskScore result to a file
        
        
        
        let textField0 = UITextView(frame: CGRect(x: 90, y: 150, width: 250, height: 50))
        textField0.text = "Your COVID exposure level is: "
        textField0.textColor = .white
        textField0.isEditable = false
        textField0.font = UIFont(name: "Arial", size: 20)
        
        let textField = UITextView(frame: CGRect(x: 100, y: 200, width: 250, height: 100))
        textField.text = self.level
        textField.textColor = .green
        textField.isEditable = false
        textField.font = UIFont(name: "Arial", size: 50)
        
        let button = UIButton(frame: CGRect(x: 100, y: 500, width: 200, height: 50))
        button.layer.cornerRadius = 5
        button.backgroundColor = .orange
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.black.cgColor
        button.setTitle("Get Test Result", for: .normal)
        button.addTarget(self, action: #selector(buttonAction), for: .touchUpInside)

        let button2 = UIButton(frame: CGRect(x: 100, y: 600, width: 200, height: 50))
        button2.layer.cornerRadius = 5
        button2.backgroundColor = .white
        button2.layer.borderWidth = 1
        button2.layer.borderColor = UIColor.black.cgColor
        button2.setTitle("Report Positive", for: .normal)
        button2.setTitleColor(.red, for: .normal)
        button2.addTarget(self, action: #selector(reportPositive), for: .touchUpInside)
        
        let button3 = UIButton(frame: CGRect(x: 100, y: 700, width: 200, height: 50))
        button3.layer.cornerRadius = 5
        button3.backgroundColor = .gray
        button3.setTitle("Stop Service", for: .normal)
//        button3.setTitleColor(.red, for: .normal)
        button3.addTarget(self, action: #selector(stopService), for: .touchUpInside)
        
        
        let button4 = UIButton(frame: CGRect(x: 100, y: 400, width: 200, height: 50))
        button4.layer.cornerRadius = 5
        button4.backgroundColor = .green
        button4.setTitle("Start service", for: .normal)
//        button4.setTitleColor(.red, for: .normal)
        button4.addTarget(self, action: #selector(startService), for: .touchUpInside)
        
        self.view.addSubview(textField0)
        self.view.addSubview(textField)
        self.view.addSubview(button)
        self.view.addSubview(button2)
        self.view.addSubview(button3)
        self.view.addSubview(button4)
        
//        if self.start {
//            button.isHidden = false
//            button2.isHidden = false
//            button3.isHidden = false
//            button4.isHidden = true
//
//        }
//        else {
//            button.isHidden = true
//            button2.isHidden = true
//            button3.isHidden = true
//            button4.isHidden = false
//        }
        
        
//        do {
//            try HelloWorld.run()
//        } catch {
//          print("Greeter failed: \(error)")
//        }
//        TokenController.didFinishLaunching()
//        TokenController.startFresh()  // delete previous file
//        TokenController.start()
    }
    @objc func buttonAction(sender: UIButton!) {
        print("buttonAction")
    }
    
    @objc func reportPositive(sender: UIButton!) {
      print("reportPositive")
    }
    
    @objc func startService(sender: UIButton!) {
        print("Start Contact Tracing")
        self.start = true
        TokenController.didFinishLaunching()
        TokenController.startFresh()  // delete previous file
        TokenController.start()
    }
    
    @objc func stopService(sender: UIButton!) {
        print("Stop service")
        self.start = false
        
    }
    
}
