//
//  ViewController.swift
//  ble_test
//
//  Created by Jiani Wang on 2022/4/22.
//

import UIKit
import CoreBluetooth
import CoreLocation

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
    private var myTAClient: TAClient!
    private var myRiskScoreController: RiskScoreController = RiskScoreController()
    private var level: String = "low level"
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        print("Start Bluetooth")
        
        // Get today's level here: Write the riskScore result to a file
        let timer2 = Timer.scheduledTimer(timeInterval: tokenGenInterval, target: self, selector: #selector(todayTask), userInfo: nil, repeats: true)
         
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
        
        let button0 = UIButton(frame: CGRect(x: 100, y: 300, width: 200, height: 50))
        button0.layer.cornerRadius = 5
        button0.backgroundColor = .green
        button0.setTitle("Start service", for: .normal)
//        button4.setTitleColor(.red, for: .normal)
        button0.addTarget(self, action: #selector(startService), for: .touchUpInside)
        
        let button1 = UIButton(frame: CGRect(x: 100, y: 400, width: 200, height: 50))
        button1.layer.cornerRadius = 5
        button1.backgroundColor = .orange
        button1.layer.borderWidth = 1
        button1.layer.borderColor = UIColor.black.cgColor
        button1.setTitle("Start Test", for: .normal)
        button1.addTarget(self, action: #selector(startTest), for: .touchUpInside)
        
        let button2 = UIButton(frame: CGRect(x: 100, y: 500, width: 200, height: 50))
        button2.layer.cornerRadius = 5
        button2.backgroundColor = .orange
        button2.layer.borderWidth = 1
        button2.layer.borderColor = UIColor.black.cgColor
        button2.setTitle("Get Test Result", for: .normal)
        button2.addTarget(self, action: #selector(getTestResult), for: .touchUpInside)

        let button3 = UIButton(frame: CGRect(x: 100, y: 600, width: 200, height: 50))
        button3.layer.cornerRadius = 5
        button3.backgroundColor = .white
        button3.layer.borderWidth = 1
        button3.layer.borderColor = UIColor.black.cgColor
        button3.setTitle("Report Positive", for: .normal)
        button3.setTitleColor(.red, for: .normal)
        button3.addTarget(self, action: #selector(reportPositive), for: .touchUpInside)
        
        let button4 = UIButton(frame: CGRect(x: 100, y: 700, width: 200, height: 50))
        button4.layer.cornerRadius = 5
        button4.backgroundColor = .gray
        button4.setTitle("Stop Service", for: .normal)
//        button3.setTitleColor(.red, for: .normal)
        button4.addTarget(self, action: #selector(stopService), for: .touchUpInside)
        
        self.view.addSubview(textField0)
        self.view.addSubview(textField)
        self.view.addSubview(button0)
        self.view.addSubview(button1)
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
    
//     func startTAClient() {
//         self.myTAClient.prepStartTest()
//         for i in 0..<2 {
//             self.myTAClient.prepGetResult()
//         }
//     }
    
    @objc func startTest(sender: UIButton!) {
        print("Start test")
        self.myTAClient = TAClient()
        self.myTAClient.prepStartTest()

    }
    
    @objc func getTestResult(sender: UIButton!) {
        print("getTestResult")
        self.myTAClient.prepGetResult()

    }
    
    @objc func reportPositive(sender: UIButton!) {
        print("reportPositive")
        
    }
    
    @objc func startService(sender: UIButton!) {
        print("Start Contact Tracing")
        self.start = true
        
        // Get today's level here: Write the riskScore result to a file
        let timer2 = Timer.scheduledTimer(timeInterval: tokenGenInterval, target: self, selector: #selector(todayTask), userInfo: nil, repeats: true)
        
//        TokenController.didFinishLaunching()
//        TokenController.startFresh()  // delete previous file
//        TokenController.start()
   }

    
    @objc func stopService(sender: UIButton!) {
        print("Stop service")
        self.start = false
        print(self.start)
    }
    
    public func createMyExpKey() {
        let url = File.myExposureKeys.dayURL(date: Date())
        File.myExposureKeys.createFile(url: url)
        print("\(url) creation success")
    }
    
    public func createMyTokens() {
        let url = File.myTokens.dayURL(date: Date())
        File.myTokens.createFile(url: url)
        print("\(url) creation success")
    }
    
    public func createPeerTokens() {
        let url = File.peerTokens.dayURL(date: Date())
        File.peerTokens.createFile(url: url)
        print("\(url) creation success")
    }
    
    @objc func todayTask() {
        if self.start{
            print("This is today's Task")
            // 0. Create all the files locally
            createMyExpKey()
            createMyTokens()
            createPeerTokens()
            // 1. Generate an exposure key, Store to the file.
            let exposureKey = ExpKey.next().data
            print("Today's exposure key is: \(exposureKey)")

            let token = TokenObject(eninterval: ENInterval.value(), payload: exposureKey, rssi: 0, lat: CLLocationDegrees(), long: CLLocationDegrees())  //
            var exposurekeyList: TokenList = [token]
            exposurekeyList.daySave(to:.myExposureKeys, day: Date())  // save to file
            
            // 2. Poll for negtive and positve exposure keys, calculate risk score
            self.myRiskScoreController.calculate()
            self.level = self.myRiskScoreController.getLevel()
            
            // 3. show today's risk level
            let textField = UITextView(frame: CGRect(x: 100, y: 200, width: 250, height: 100))
            textField.text = self.level
            textField.textColor = .red
            textField.isEditable = false
            textField.font = UIFont(name: "Arial", size: 50)
            self.view.addSubview(textField)
            
        }else{
            print("Service not start. Do not do today's task")
        }
        
    }
    
}
