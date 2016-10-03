//
//  Meta+CoreDataClass.swift
//  VirtualTourist
//
//  Created by Laura Scully on 3/10/2016.
//  Copyright © 2016 laura.sempere.com. All rights reserved.
//

import Foundation
import CoreData


public class Meta: NSManagedObject {
    convenience init(pages: Int32, page:Int32, pin:Pin, context: NSManagedObjectContext) {
        if let entity = NSEntityDescription.entity(forEntityName: "Meta", in: context) {
            self.init(entity: entity, insertInto: context)
            self.pages = pages
            self.page = page
            self.pin = pin
        } else {
            fatalError("No entity Pin found")
        }
    }

}
