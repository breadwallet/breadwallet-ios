//
//  BRCoding.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 8/14/16.
//  Copyright © 2016 Aaron Voisine. All rights reserved.
//

import Foundation

// BRCoder/BRCoding works a lot like NSCoder/NSCoding but simpler
// instead of using optionals everywhere we just use zero values, and take advantage
// of the swift type system somewhat to make the whole api a little cleaner
protocol BREncodable {
    // return anything that is JSON-able
    func encode() -> AnyObject
    // zeroValue is a zero-value initializer
    static func zeroValue() -> Self
    // decode can be passed any value which is json-able
    static func decode(_ value: AnyObject) -> Self
}


// An object which can encode and decode values
open class BRCoder {
    var data: [String: AnyObject]
    
    init(data: [String: AnyObject]) {
        self.data = data
    }
    
    func encode(_ obj: BREncodable, key: String) {
        self.data[key] = obj.encode()
    }
    
    func decode<T: BREncodable>(_ key: String) -> T {
        guard let d = self.data[key] else {
            return T.zeroValue()
        }
        return T.decode(d)
    }
}

// An object which may be encoded/decoded using the archiving/unarchiving classes below
protocol BRCoding {
    init?(coder decoder: BRCoder)
    func encode(_ coder: BRCoder)
}

// A basic analogue of NSKeyedArchiver, except it uses JSON and uses
open class BRKeyedArchiver {
    static func archivedDataWithRootObject(_ obj: BRCoding, compressed: Bool = true) -> Data {
        let coder = BRCoder(data: [String : AnyObject]())
        obj.encode(coder)
        do {
            let j = try JSONSerialization.data(withJSONObject: coder.data, options: [])
            guard let bz = (compressed ? j.bzCompressedData : j) else {
                print("compression error")
                return Data()
            }
            return bz
        } catch let e {
            print("BRKeyedArchiver unable to archive object: \(e)")
            return "{}".data(using: String.Encoding.utf8)!
        }
    }
}

// A basic analogue of NSKeyedUnarchiver
open class BRKeyedUnarchiver {
    static func unarchiveObjectWithData<T: BRCoding>(_ data: Data, compressed: Bool = true) -> T? {
        do {
            guard let bz = (compressed ? Data(bzCompressedData: data) : data),
                let j = try JSONSerialization.jsonObject(with: bz, options: []) as? [String: AnyObject] else {
                print("BRKeyedUnarchiver invalid json object, or invalid bz data")
                return nil
            }
            let coder = BRCoder(data: j)
            return T(coder: coder)
        } catch let e {
            print("BRKeyedUnarchiver unable to deserialize JSON: \(e)")
            return nil
        }
        
    }
}

// converters

extension Date: BREncodable {
    func encode() -> AnyObject {
        return self.timeIntervalSinceReferenceDate as AnyObject
    }
    
    public static func zeroValue() -> Date {
        return dateFromTimeIntervalSinceReferenceDate(0)
    }
    
    public static func decode(_ value: AnyObject) -> Date {
        let d = (value as? Double) ?? Double()
        return dateFromTimeIntervalSinceReferenceDate(d)
    }
    
    static func dateFromTimeIntervalSinceReferenceDate<T>(_ d: Double) -> T {
        return Date(timeIntervalSinceReferenceDate: d) as! T
    }
}

extension Int: BREncodable {
    func encode() -> AnyObject {
        return self as AnyObject
    }
    
    static func zeroValue() -> Int {
        return 0
    }
    
    static func decode(_ s: AnyObject) -> Int {
        return (s as? Int) ?? self.zeroValue()
    }
}

extension Double: BREncodable {
    func encode() -> AnyObject {
        return self as AnyObject
    }
    
    static func zeroValue() -> Double {
        return 0.0
    }
    
    static func decode(_ s: AnyObject) -> Double {
        return (s as? Double) ?? self.zeroValue()
    }
}

extension String: BREncodable {
    func encode() -> AnyObject {
        return self as AnyObject
    }
    
    static func zeroValue() -> String {
        return ""
    }
    
    static func decode(_ s: AnyObject) -> String {
        return (s as? String) ?? self.zeroValue()
    }
}
