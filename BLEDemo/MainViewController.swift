//
//  MainViewController.swift
//  CompassCompanion
//
//  Created by Rick Smith on 04/07/2016.
//  Copyright © 2016 Rick Smith. All rights reserved.
//

import UIKit
import CoreBluetooth

// Delegate functions
protocol BluetoothSerialDelegate: class {
    // ** Required **
    
    /// Called when de state of the CBCentralManager changes (e.g. when bluetooth is turned on/off)
    func serialDidChangeState()
    
    /// Called when a peripheral disconnected
    func serialDidDisconnect(_ peripheral: CBPeripheral, error: NSError?)
    
    // ** Optionals **
    
    /// Called when a message is received
    func serialDidReceiveString(_ message: String)
    
    /// Called when a message is received
    func serialDidReceiveBytes(_ bytes: [UInt8])
    
    /// Called when a message is received
    func serialDidReceiveData(_ data: Data)
    
    /// Called when the RSSI of the connected peripheral is read
    func serialDidReadRSSI(_ rssi: NSNumber)
    
    /// Called when a new peripheral is discovered while scanning. Also gives the RSSI (signal strength)
    func serialDidDiscoverPeripheral(_ peripheral: CBPeripheral, RSSI: NSNumber?)
    
    /// Called when a peripheral is connected (but not yet ready for cummunication)
    func serialDidConnect(_ peripheral: CBPeripheral)
    
    /// Called when a pending connection failed
    func serialDidFailToConnect(_ peripheral: CBPeripheral, error: NSError?)

    /// Called when a peripheral is ready for communication
    func serialIsReady(_ peripheral: CBPeripheral)
}

// Make some of the delegate functions optional
extension BluetoothSerialDelegate {
    func serialDidReceiveString(_ message: String) {}
    func serialDidReceiveBytes(_ bytes: [UInt8]) {}
    func serialDidReceiveData(_ data: Data) {}
    func serialDidReadRSSI(_ rssi: NSNumber) {}
    func serialDidDiscoverPeripheral(_ peripheral: CBPeripheral, RSSI: NSNumber?) {}
    func serialDidConnect(_ peripheral: CBPeripheral) {}
    func serialDidFailToConnect(_ peripheral: CBPeripheral, error: NSError?) {}
    func serialIsReady(_ peripheral: CBPeripheral) {}
}

class MainViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    var manager:CBCentralManager? = nil
    var mainPeripheral:CBPeripheral? = nil
    var mainCharacteristic:CBCharacteristic? = nil
    /// The delegate object the BluetoothDelegate methods will be called upon
    weak var delegate: BluetoothSerialDelegate?
    

    let BLEService = "DFB0"
    let BLECharacteristic = "DFB1"
    
    @IBOutlet weak var recievedMessageText: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        manager = CBCentralManager(delegate: self, queue: nil);
        
        customiseNavigationBar()
    }
    
    func customiseNavigationBar () {
        
        self.navigationItem.rightBarButtonItem = nil
        
        let rightButton = UIButton()
        
        if (mainPeripheral == nil) {
            rightButton.setTitle("Scan", for: [])
            rightButton.setTitleColor(UIColor.blue, for: [])
            rightButton.frame = CGRect(origin: CGPoint(x: 0,y :0), size: CGSize(width: 60, height: 30))
            rightButton.addTarget(self, action: #selector(self.scanButtonPressed), for: .touchUpInside)
        } else {
            rightButton.setTitle("Disconnect", for: [])
            rightButton.setTitleColor(UIColor.blue, for: [])
            rightButton.frame = CGRect(origin: CGPoint(x: 0,y :0), size: CGSize(width: 100, height: 30))
            rightButton.addTarget(self, action: #selector(self.disconnectButtonPressed), for: .touchUpInside)
        }
        
        let rightBarButton = UIBarButtonItem()
        rightBarButton.customView = rightButton
        self.navigationItem.rightBarButtonItem = rightBarButton
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if (segue.identifier == "scan-segue") {
            let scanController : ScanTableViewController = segue.destination as! ScanTableViewController
            
            //set the manager's delegate to the scan view so it can call relevant connection methods
            manager?.delegate = scanController
            scanController.manager = manager
            scanController.parentView = self
        }
        
    }
    
    // MARK: Button Methods
    @objc func scanButtonPressed() {
        performSegue(withIdentifier: "scan-segue", sender: nil)
    }
    
    @objc func disconnectButtonPressed() {
        //this will call didDisconnectPeripheral, but if any other apps are using the device it will not immediately disconnect
        manager?.cancelPeripheralConnection(mainPeripheral!)
    }
    
    @IBAction func sendButtonPressed(_ sender: AnyObject) {
        let helloWorld = "Hello World!"
        let dataToSend = helloWorld.data(using: String.Encoding.utf8)
        
        if (mainPeripheral != nil) {
//            mainPeripheral?.writeValue(dataToSend!, for: mainCharacteristic!, type: CBCharacteristicWriteType.withoutResponse)
        } else {
            print("haven't discovered device yet")
        }
    }
    
    // MARK: - CBCentralManagerDelegate Methods    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        mainPeripheral = nil
        customiseNavigationBar()
        print("Disconnected" + peripheral.name!)
    }
    
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print(central.state)
    }
    
    // MARK: CBPeripheralDelegate Methods
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        for service in peripheral.services! {
            
            print("Service found with UUID: " + service.uuid.uuidString)
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {

        //get device name
        if (service.uuid.uuidString == "1800") {
            
            for characteristic in service.characteristics! {
                
                if (characteristic.uuid.uuidString == "2A00") {
                    peripheral.readValue(for: characteristic)
                    print("Found Device Name Characteristic")
                }
                
            }
            
        }
        
        for characteristic in service.characteristics! {
            peripheral.setNotifyValue(true, for: characteristic)
        }
        
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let data = characteristic.value
        print("UUID String=" + characteristic.uuid.uuidString)
        print(data!.count)
        var bytes = [UInt8](repeating: 0, count: data!.count / MemoryLayout<UInt8>.size)
        (data! as NSData).getBytes(&bytes, length: data!.count)

        
        var dataMap = bytes.map { String(format: "%02x ", $0)}.joined();
        print(dataMap)
//        if let string = String(bytes: bytes, encoding: .utf8) {
//            print("This string " + string)
//        } else {
//            print("not a valid UTF-8 sequence")
//        }

        if (characteristic.uuid.uuidString == "2A00") {
            //value for device name recieved
            let deviceName = characteristic.value
            print(deviceName)
        } else if (characteristic.uuid.uuidString == "2A29") {
            //value for manufacturer name recieved
            let manufacturerName = characteristic.value
            print(manufacturerName)
        } else if (characteristic.uuid.uuidString == "2A23") {
            //value for system ID recieved
            let systemID = characteristic.value
            print(systemID)
        } else if (characteristic.uuid.uuidString == BLECharacteristic) {
            //data recieved
            if(characteristic.value != nil) {
                let stringValue = String(data: characteristic.value!, encoding: String.Encoding.utf8)!
            
                recievedMessageText.text = stringValue
                print("Received... " + stringValue)
            }
        }
        
        
    }
    
}

