//
//  Photo+CoreDataProperties.swift
//  VirtualTourist
//
//  Created by Laura Scully on 30/10/2016.
//  Copyright © 2016 laura.sempere.com. All rights reserved.
//

import Foundation
import CoreData

extension Photo {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Photo> {
        return NSFetchRequest<Photo>(entityName: "Photo");
    }

    @NSManaged public var image: NSData?
    @NSManaged public var meta: Meta?
    @NSManaged public var pin: Pin?

}
