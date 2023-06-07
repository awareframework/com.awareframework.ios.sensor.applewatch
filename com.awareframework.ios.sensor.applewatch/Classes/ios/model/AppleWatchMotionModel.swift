import UIKit
import com_awareframework_ios_sensor_core

public class AppleWatchMotionData: AwareObject {

    public static let TABLE_NAME = "appleWatchMotionData"
    
    @objc dynamic public var acc_x:Double = 0
    @objc dynamic public var acc_y:Double = 0
    @objc dynamic public var acc_z:Double = 0
    @objc dynamic public var user_acc_x:Double = 0
    @objc dynamic public var user_acc_y:Double = 0
    @objc dynamic public var user_acc_z:Double = 0
    @objc dynamic public var roll:Double = 0
    @objc dynamic public var pitch:Double = 0
    @objc dynamic public var yaw:Double = 0
    @objc dynamic public var gravity_x:Double = 0
    @objc dynamic public var gravity_y:Double = 0
    @objc dynamic public var gravity_z:Double = 0
    @objc dynamic public var rotation_x:Double = 0
    @objc dynamic public var rotation_y:Double = 0
    @objc dynamic public var rotation_z:Double = 0
    
    public override func toDictionary() -> Dictionary<String, Any> {
        var dict = super.toDictionary()
        dict["acc_x"] = acc_x
        dict["acc_y"] = acc_y
        dict["acc_z"] = acc_z
        dict["user_acc_x"] = user_acc_x
        dict["user_acc_y"] = user_acc_y
        dict["user_acc_z"] = user_acc_z
        dict["roll"] = roll
        dict["pitch"] = pitch
        dict["yaw"] = yaw
        dict["gravity_x"] = gravity_x
        dict["gravity_y"] = gravity_y
        dict["gravity_z"] = gravity_z
        dict["rotation_x"] = rotation_x
        dict["rotation_y"] = rotation_y
        dict["rotation_z"] = rotation_z
        return dict
    }
    
}


public class AppleWatchAudioData: AwareObject {

    public static let TABLE_NAME = "appleWatchAudioData"
    
    @objc dynamic public var decibel:Double = 0
    
    public override func toDictionary() -> Dictionary<String, Any> {
        var dict = super.toDictionary()
        dict["decibel"] = decibel
        return dict
    }
    
}


public class AppleWatchAudioFileData: AwareObject {

    public static let TABLE_NAME = "appleWatchAudioFileData"
    
    @objc dynamic public var file_name:String = ""
    
    public override func toDictionary() -> Dictionary<String, Any> {
        var dict = super.toDictionary()
        dict["file_name"] = file_name
        return dict
    }
    
}

public class AppleWatchHeartRateData: AwareObject {

    public static let TABLE_NAME = "appleWatchHeartRateData"
    
    @objc dynamic public var hr:Double = 0
    
    public override func toDictionary() -> Dictionary<String, Any> {
        var dict = super.toDictionary()
        dict["hr"] = hr
        return dict
    }
    
}

public class AppleWatchBatteryData: AwareObject {

    public static let TABLE_NAME = "appleWatchBatteryData"
    
    @objc dynamic public var battery_level:Double = 0
    @objc dynamic public var battery_state:Int = 0
    
    public override func toDictionary() -> Dictionary<String, Any> {
        var dict = super.toDictionary()
        dict["battery_level"] = battery_level
        dict["battery_state"] = battery_state
        return dict
    }
    
}

public class AppleWatchHeadingData: AwareObject {
    public static let TABLE_NAME = "appleWatchHeadingData"
    
    @objc dynamic public var true_heading:Double = 0
    @objc dynamic public var magnetic_heading:Double = 0
    @objc dynamic public var heading_accuracy:Double = 0
    @objc dynamic public var x:Double = 0
    @objc dynamic public var y:Double = 0
    @objc dynamic public var z:Double = 0
    
    public override func toDictionary() -> Dictionary<String, Any> {
        var dict = super.toDictionary()
        dict["true_heading"] = true_heading
        dict["magnetic_heading"] = magnetic_heading
        dict["heading_accuracy"] = heading_accuracy
        dict["x"] = x
        dict["y"] = y
        dict["z"] = z
        return dict
    }
}

public class AppleWatchLocationData: AwareObject {
    public static let TABLE_NAME = "appleWatchLocationData"
    
    @objc dynamic public var latitude:Double = 0
    @objc dynamic public var longitude:Double = 0
    @objc dynamic public var altitude:Double = 0
    @objc dynamic public var ellipsoidal_altitude:Double = 0
    @objc dynamic public var horizontal_accuracy:Double = 0
    @objc dynamic public var vertical_accuracy:Double = 0
    @objc dynamic public var speed:Double = 0
    @objc dynamic public var speed_accuracy:Double = 0
    @objc dynamic public var course:Double = 0
    @objc dynamic public var course_accuracy:Double = 0
    
    public override func toDictionary() -> Dictionary<String, Any> {
        var dict = super.toDictionary()
        dict["latitude"] = latitude
        dict["longitude"] = longitude
        dict["altitude"] = altitude
        dict["ellipsoidal_altitud"] = ellipsoidal_altitude
        dict["horizontal_accuracy"] = horizontal_accuracy
        dict["vertical_accuracy"] = vertical_accuracy
        dict["speed"] = speed
        dict["speed_accuracy"] = speed_accuracy
        dict["course"] = course
        dict["course_accuracy"] = course_accuracy
        return dict
    }
}


public class AppleWatchAudioClassifierData: AwareObject {

    public static let TABLE_NAME = "appleWatchAudioClassifierData"
    
    @objc dynamic public var identifier:String = ""
    @objc dynamic public var confidence:Double = 0.0
    
    public override func toDictionary() -> Dictionary<String, Any> {
        var dict = super.toDictionary()
        dict["identifier"] = identifier
        dict["confidence"] = confidence
        return dict
    }
    
}
