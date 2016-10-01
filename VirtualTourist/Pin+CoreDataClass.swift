//
//  Pin+CoreDataClass.swift
//  VirtualTourist
//
//  Created by Laura Scully on 2/10/2016.
//  Copyright © 2016 laura.sempere.com. All rights reserved.
//

import Foundation
import CoreData


public class Pin: NSManagedObject {

    convenience init(longitude:Double, latitude:Double, context: NSManagedObjectContext) {
        if let entity = NSEntityDescription.entity(forEntityName: "Pin", in: context) {
            self.init(entity: entity, insertInto: context)
            self.longitude = longitude
            self.latitude = latitude
        } else {
            fatalError("No entity Pin found")
        }
    }
}
