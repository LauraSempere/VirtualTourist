//
//  PhotoAlbumViewController.swift
//  VirtualTourist
//
//  Created by Laura Scully on 2/10/2016.
//  Copyright © 2016 laura.sempere.com. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class PhotoAlbumViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, NSFetchedResultsControllerDelegate {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var actionButton: UIBarButtonItem!
    @IBOutlet weak var activityIndicator:UIActivityIndicatorView!
    
    var context:NSManagedObjectContext!
    var bgContext:NSManagedObjectContext!
    var blockOperations:[BlockOperation] = [BlockOperation]()
    var location:Pin!
    var meta:Meta!
    var photos:[Photo] = [Photo]()
    let flickr = FlickrClient.sharedInstance()
    var photoResults: [[String:AnyObject]] = []
    
    var selectedPhotos:[IndexPath: Photo] = [:]
    var editMode:Bool = false
    
    //    var insertedIndexPaths: [IndexPath]!
    //    var deletedIndexPaths : [IndexPath]!
    //    var updatedIndexPaths : [IndexPath]!
    //
    
    var fetchedResultController:NSFetchedResultsController<Photo>!
    
    @IBAction func excuteAction(_ sender: AnyObject) {
        if editMode {
            self.context.performAndWait {
                for (k, selected) in self.selectedPhotos {
                    self.context.delete(selected)
                    self.collectionView.deleteItems(at: [k])
                    self.collectionView.reloadData()
                }
                
                self.selectedPhotos = [:]
                do {
                    try self.context.save()
                    print("Remove Selected Images")
                } catch let error {
                    print("Error removing photos: \(error)")
                }
                //collectionView.reloadData()
                
            }
            
            
            //selectedPhotos = [:]
            //            do {
            //                try context.save()
            //                print("Remove Selected Images")
            //            } catch let error {
            //                print("Error removing photos: \(error)")
            //            }
            //collectionView.reloadData()
            
        } else {
            removeMeta()
            print("Get new images from Flickr")
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let request:NSFetchRequest<Photo> = Photo.fetchRequest()
        let predicate:NSPredicate = NSPredicate(format: "pin = %@", location)
        let sortDescriptor = NSSortDescriptor(key: "image", ascending: true)
        request.sortDescriptors = [sortDescriptor]
        request.predicate = predicate
        context.automaticallyMergesChangesFromParent = true
        
        fetchedResultController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultController.delegate = self

        getPhotosForCurrentLocation()
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.allowsMultipleSelection = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        getPhotosForCurrentLocation()
        
        if (fetchedResultController.fetchedObjects?.count)! > 0 {
            toggleLoadingState(loading: false)
        } else {
            toggleLoadingState(loading: false)
            getPhotosFromFlickr(locID: location.objectID)
        }
        
        
    }
    
    func getPhotosForCurrentLocation(){
        do {
            try fetchedResultController.performFetch()
        } catch let error {
            print("Error getting photos for current location: \(error)")
        }
        
    }
    
    
    func toggleLoadingState(loading: Bool){
        if loading {
            activityIndicator.startAnimating()
            activityIndicator.isHidden = false
            collectionView.isHidden = true
        } else {
            activityIndicator.stopAnimating()
            activityIndicator.isHidden = true
            collectionView.isHidden = false
        }
    }
    
    func toggleEditMode(edit: Bool){
        if edit {
            editMode = true
            actionButton.title = "Delete Selected Photos"
        } else {
            editMode = false
            actionButton.title = "Get More Images"
        }
    }
    
    
    func showPhotos() {
        print("Job Done")
        //getPhotosForCurrentLocation()
        performUIUpdatesOnMain {
            self.toggleLoadingState(loading: false)
            //self.collectionView.reloadData()
        }
        
    }
    
    func getImageForPhoto(index:Int, completionHandler: @escaping (_ success:Bool, _ photoData:NSData?)-> Void) {
        if photoResults.count > index {
            DispatchQueue.global(qos: .userInitiated).async {
                
                if let urlString = self.photoResults[index]["url_m"] as? String {
                    if let imageData = NSData(contentsOf: URL(string: urlString)!) {
                        DispatchQueue.main.async {
                            completionHandler(true, imageData)
                        }
                        
                    }
                    DispatchQueue.main.async {
                        completionHandler(false, nil)
                    }
                } else {
                    DispatchQueue.main.async {
                        completionHandler(false, nil)
                    }
                }
                
            }
        }
    }
    
    
    func removeMeta() {
        toggleLoadingState(loading: true)
        //        context.performAndWait {
        //            for photo in self.fetchedResultController.fetchedObjects! {
        //                self.context.delete(photo)
        //            }
        //            do {
        //                try self.context.save()
        //
        //            } catch let err {
        //                print("Deleting objetcs error: \(err)")
        //            }
        //        }
        //        collectionView.reloadData()
       // getPhotosFromFlickr()
    }
    
    
    func getPhotosFromFlickr(locID:NSManagedObjectID) {
        self.flickr.getPhotosForLocation(location: location) { (success, results, meta, errorString) in
            if success {
                var loc:Pin!
                
                self.bgContext.performAndWait {
                    do {
                        loc = try self.bgContext.existingObject(with: locID) as! Pin
                    } catch let err {
                        print("Error getting location in bgContext... \(err)")
                    }
                }
                
                self.bgContext.performAndWait {
                        if let prevMeta = loc.meta {
                            print("Removing prev meta")
                            self.bgContext.delete(prevMeta)
                            
                            do {
                                try self.bgContext.save()
                                //self.getPhotosForCurrentLocation()
                            } catch let err {
                                print("Error removing meta: \(err)")
                            }
                        }
                        

                }
                
                //self.showPhotos()
                
                self.bgContext.performAndWait {
                    guard let meta = meta else {return}
                    guard let results = results else {return}
                    self.photoResults = results
                    var newMeta = Meta(context: self.bgContext)
                    newMeta.page = Int32(meta["page"]!)
                    newMeta.pages = Int32(meta["pages"]!)
                    
                    newMeta.pin = loc
                    loc.meta = newMeta
                    
                    
                    for result in results {
                        var newPhoto = Photo(context: self.bgContext)
                        newPhoto.pin = loc
                        newPhoto.meta = newMeta
                    }
                    
                    do {
                        print("Before saving BG Context +++")
                        try self.bgContext.save()
                    } catch let error {
                        print("Error saving photos: \(error)")
                    }
                    
                }
                
                performUIUpdatesOnMain {
                    print("Refreshing All Objects")
                    //self.bgContext.automaticallyMergesChangesFromParent
                    //self.getPhotosForCurrentLocation()
                }
                
            }
        }
        
    }
    
    
    
    
    // MARK: CollectionView Data Source
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        if let sections = fetchedResultController.sections {
            return sections.count
        }
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let sections = fetchedResultController.sections {
            let currentSection = sections[section]
            return currentSection.numberOfObjects
        }
        
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoAlbumCell", for: indexPath) as! PhotoAlbumCell
        cell.image.isHidden = true
        
        if let savedImageData = fetchedResultController.object(at: indexPath).image {
            cell.image.isHidden = false
            cell.image.image = UIImage(data: savedImageData as Data)
            cell.activityIndicator.stopAnimating()
            cell.activityIndicator.isHidden = true
        } else {
            cell.activityIndicator.startAnimating()
            cell.activityIndicator.isHidden = false
            cell.backgroundColor = UIColor.orange
//           let photo = fetchedResultController.object(at: indexPath)
//            getImageForPhoto(index: indexPath.item, completionHandler: { (success, imageData) in
//                if success {
//                    photo.image = imageData
//                    do {
//                        try self.context.save()
//                        self.collectionView.reloadItems(at: [indexPath])
//                    } catch let error {
//                        print("Error saving image data:\(error)")
//                    }
//                }
//            })
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if !editMode {
            toggleEditMode(edit: true)
        }
        
        let selectedPhoto = fetchedResultController.object(at: indexPath)
        selectedPhotos[indexPath] = selectedPhoto
        let cell = collectionView.cellForItem(at: indexPath) as! PhotoAlbumCell
        cell.backgroundColor = UIColor.cyan
        cell.alpha = 0.4
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        let selectedPhoto = fetchedResultController.object(at: indexPath)
        //selectedPhotos = selectedPhotos.filter(){$0 != selectedPhoto}
        selectedPhotos.removeValue(forKey: indexPath)
        let cell = collectionView.cellForItem(at: indexPath) as! PhotoAlbumCell
        cell.backgroundColor = UIColor.orange
        cell.alpha = 1
        
        if selectedPhotos.isEmpty {
            toggleEditMode(edit: false)
        }
    }
    
    
    //    MARK NSFetchedResultsControllerDelegate

    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        blockOperations = [BlockOperation]()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            let op = BlockOperation {
                if let indexPath = newIndexPath {
                    self.collectionView.insertItems(at: [indexPath])
                }
            }
            blockOperations.append(op)
            
        case .update: // Update
            //guard let newIndexPath = newIndexPath else { return }
            let op = BlockOperation { print("Update Operation was Detected +++")}
            blockOperations.append(op)
            
        case .move: // Move
            //guard let indexPath = indexPath else { return }
            //guard let newIndexPath = newIndexPath else { return }
            let op = BlockOperation { print("Move Operation was Detected +++")}
            blockOperations.append(op)
            
        case .delete: // Delete
           // guard let newIndexPath = newIndexPath else { return }
            let op = BlockOperation { print("Delete Operation was Detected +++")}
            blockOperations.append(op)
        default: break
        }
    }
    
    
    
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        
        print("Perform updates!")
        collectionView.performBatchUpdates({
            for operation in self.blockOperations {
                operation.start()
            }
        }) { (finished) in
            self.blockOperations.removeAll(keepingCapacity: false)
        }
    }
    
    
}

