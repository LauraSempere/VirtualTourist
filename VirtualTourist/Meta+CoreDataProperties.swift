//
//  Meta+CoreDataProperties.swift
//  VirtualTourist
//
//  Created by Laura Scully on 1/11/2016.
//  Copyright © 2016 laura.sempere.com. All rights reserved.
//

import Foundation
import CoreData

extension Meta {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Meta> {
        return NSFetchRequest<Meta>(entityName: "Meta");
    }

    @NSManaged public var page: Int32
    @NSManaged public var pages: Int32
    @NSManaged public var photos: NSSet?
    @NSManaged public var pin: Pin?

}

// MARK: Generated accessors for photos
extension Meta {

    @objc(addPhotosObject:)
    @NSManaged public func addToPhotos(_ value: Photo)

    @objc(removePhotosObject:)
    @NSManaged public func removeFromPhotos(_ value: Photo)

    @objc(addPhotos:)
    @NSManaged public func addToPhotos(_ values: NSSet)

    @objc(removePhotos:)
    @NSManaged public func removeFromPhotos(_ values: NSSet)

}
