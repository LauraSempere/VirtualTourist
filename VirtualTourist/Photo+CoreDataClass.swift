//
//  Photo+CoreDataClass.swift
//  VirtualTourist
//
//  Created by Laura Scully on 3/10/2016.
//  Copyright © 2016 laura.sempere.com. All rights reserved.
//

import Foundation
import CoreData


public class Photo: NSManagedObject {
    
    
    convenience init(image: NSData?, pin: Pin, meta:Meta, context: NSManagedObjectContext) {
        
        if let entity = NSEntityDescription.entity(forEntityName: "Photo", in: context) {
            self.init(entity: entity, insertInto: context)
            self.pin = pin
            self.meta = meta
            
            if let img = image {
                self.image = img
            }
            
        } else {
            fatalError("Unable to find Entity Photo!")
        }
    }

    
}
