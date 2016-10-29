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

class PhotoAlbumViewController: UIViewController, NSFetchedResultsControllerDelegate {

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var actionButton: UIBarButtonItem!
    @IBOutlet weak var activityIndicator:UIActivityIndicatorView!
    
    var location:Pin!
    var results:[[String:AnyObject]] = [[String:AnyObject]]()
    var meta:Meta!
    var cachedPhotos = [Int: Photo]()
    let flickr = FlickrClient.sharedInstance()
    let stack = (UIApplication.shared.delegate as! AppDelegate).stack
    var selectedPhotos:[Photo] = []
    var editMode:Bool = false
    
    var insertedIndexPaths: [IndexPath]!
    var deletedIndexPaths : [IndexPath]!
    var updatedIndexPaths : [IndexPath]!
    
    @IBAction func excuteAction(_ sender: AnyObject) {
        if editMode {
            print("Remove Selected Images")
            for photo in selectedPhotos {
                stack.context.delete(photo)
            }
            do{
                try stack.context.save()
            } catch let error {
                print("Error deleting :: \(error)")
            }
        } else {
            print("Get new images from Flickr")
        }
    
    }
    
    
    lazy var fetchedResultsController: NSFetchedResultsController<Photo> = {
        let fetchReq:NSFetchRequest<Photo> = Photo.fetchRequest()
        fetchReq.returnsObjectsAsFaults = false
        fetchReq.sortDescriptors = [NSSortDescriptor(key: "image", ascending: true)]
        let pred = NSPredicate(format: "pin = %@", argumentArray: [self.location])
        fetchReq.predicate = pred
        let fc = NSFetchedResultsController(fetchRequest: fetchReq, managedObjectContext: self.stack.context, sectionNameKeyPath: nil, cacheName: nil)
        fc.delegate = self
        return fc
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.allowsMultipleSelection = true

        do {
            try fetchedResultsController.performFetch()
            print("Hi FC!!!!")
            print(fetchedResultsController.sections?[0].numberOfObjects)
        } catch let err {
            print(err)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        getSavedMeta()
        getImagesForCurrentLocation { (photos, error) in
            if let err = error {
                print("DB error: \(err)")
            } else {
                if (photos?.isEmpty)! {
                    print("Getting photos from Flickr .... ")
                    self.toggleLoadingState(loading: true)
                    
                    getImagesFromFlickr(completion: { (success) in
                        if success {
                            print("Success....")
                            let photosSaved = self.fetchedResultsController.fetchedObjects
                            for (index, photo) in photosSaved!.enumerated() {
                                let photoID = photo.objectID
                                self.getPhotoAsync(photoID: photoID, index: index)
                            }
                           // print(((photosSaved?[0] as? NSManagedObject)?.objectID)?.isTemporaryID)
                            
                            
                            
                        } else {
                            print("No success....")
                        }
                    })
                } else {
                    self.toggleLoadingState(loading: false)
                    print("Photos from DB")
                }
            
            }
        }
    }
    
    func toggleLoadingState(loading:Bool) {
        if loading {
            collectionView.isHidden = true
            activityIndicator.startAnimating()
            activityIndicator.isHidden = false
            actionButton.isEnabled = false
        } else {
            collectionView.isHidden = false
            activityIndicator.stopAnimating()
            activityIndicator.isHidden = true
            actionButton.isEnabled = true
        }
    }
    
    func setEditMode(edit: Bool) {
        if edit {
            editMode = true
            actionButton.title = "Delete selected Images"
        } else {
            editMode = false
            actionButton.title = "Get New Images"
        }
    }
 
    
    // MARK: Core Data
    func getImagesForCurrentLocation(completionHandler: (_ photos:[Photo]?, _ error: Error?) -> Void) {
        do {
            try fetchedResultsController.performFetch()
            let photos = fetchedResultsController.fetchedObjects
            completionHandler(photos, nil)
        } catch let err {
            completionHandler(nil, err)
            print(err)
        }
}
    
    func getPhotoById(id: NSManagedObjectID, completionHandler:(_ photo: Photo?, _ error: Error?) -> Void) {
        do {
            let result =  try stack.context.existingObject(with: id)
            if let photo = result as? Photo {
                completionHandler(photo, nil)
            } else {
                completionHandler(nil, nil)
            }
        } catch let err {
            completionHandler(nil, err)
            
        }
    
    }
    
    func getSavedMeta(){
        let fetchReq:NSFetchRequest<Meta> = Meta.fetchRequest()
        let pred = NSPredicate(format: "pin = %@", argumentArray: [location])
        fetchReq.predicate = pred
        do {
            let results = try stack.context.fetch(fetchReq)
            if !results.isEmpty{
                meta = results[0]
            }
        } catch let error  {
            print("Error : \(error)")
        }
    }
    
    

    
//    var blockOperations:[BlockOperation]!
//    
//    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
//        blockOperations = [BlockOperation]()
//    }
//    
//    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
//        switch type {
//        case .insert: // Insert
//            print("Inserting....")
//            guard let newIndexPath = newIndexPath else { return }
//            let op = BlockOperation { [weak self] in self?.collectionView?.insertItems(at: [newIndexPath]) }
//            blockOperations.append(op)
//            
//        case .update: // Update
//            NSLog("2. Update")
//            guard let newIndexPath = newIndexPath else { return }
//            let op = BlockOperation { [weak self] in self?.collectionView?.reloadItems(at: [newIndexPath]) }
//            blockOperations.append(op)
//            
//        case .move: // Move
//            guard let indexPath = indexPath else { return }
//            guard let newIndexPath = newIndexPath else { return }
//            let op = BlockOperation { [weak self] in self?.collectionView?.moveItem(at: indexPath, to: newIndexPath)}
//            blockOperations.append(op)
//            
//        case .delete: // Delete
//            guard let newIndexPath = newIndexPath else { return }
//            let op = BlockOperation { [weak self] in self?.collectionView?.deleteItems(at: [newIndexPath]) }
//            blockOperations.append(op)
//        default: break
//        }
//    }
//    
//    
//    
//    
//    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
//        
//        print("Perform updates!")
//        collectionView.performBatchUpdates({
//            for operation in self.blockOperations {
//                operation.start()
//            }
//        }) { (finished) in
//            self.blockOperations.removeAll(keepingCapacity: false)
//        }
//    }

    
}


// MARK: CollectionView Data Source and Delegate
extension PhotoAlbumViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    // MARK: CollectionView
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
//        if let count = fetchedResultsController.sections?[0].numberOfObjects, count > 0  {
//            return count
//        } else {
//            print("Results count ---- \(results.count)")
//            return 0
//            //return results.count
//        }
        
        return (fetchedResultsController.sections?[0].numberOfObjects)!
        
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoAlbumCell", for: indexPath) as! PhotoAlbumCell
        cell.backgroundColor = UIColor.lightGray
        cell.activityIndicator.startAnimating()
        cell.image.image = UIImage(named: "placeholder")
        
        if let savedPhoto = fetchedResultsController.object(at: indexPath) as? Photo{
            print("Saved Photo")
            if let savedImage = savedPhoto.image {
                print("Saved Image")
                cell.image.image = UIImage(data: savedImage as! Data)
            } else {
                print("Not saved Image")
            }
        } else {
            print("Not Saved Photo")
        }
        
        
//        if let savedImage = (fetchedResultsController.object(at: indexPath) as? Photo)!.image {
//            cell.image.image = UIImage(data: savedImage as! Data)
//            cell.activityIndicator.stopAnimating()
//            cell.activityIndicator.isHidden = true
//            //cell.backgroundColor = UIColor.orange
//        } else {
//            cell.backgroundColor = UIColor.darkGray
//         //   getPhotoAsync(photoID: fetchedResultsController.object(at: indexPath).objectID, index: indexPath.item)
//        }
        
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath) as! PhotoAlbumCell
        if !editMode {
            setEditMode(edit: true)
        }
       
        var id:NSManagedObjectID!
        
        if cachedPhotos.isEmpty {
            id = (fetchedResultsController.object(at: indexPath) as! Photo).objectID
        } else {
            id = cachedPhotos[indexPath.item]?.objectID
        }
        
        if let id = id {
            getPhotoById(id: id) { (photo, error) in
                if let err = error {
                    print("Error getting photo: \(err)")
                } else {
                    if let photo = photo {
                        selectedPhotos.append(photo)
                    }
                }
            }
        }
        
        cell.image.alpha = 0.25
        cell.backgroundColor = UIColor.cyan
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath) as! PhotoAlbumCell
        cell.image.alpha = 1
        cell.backgroundColor = UIColor.clear
        
        var id:NSManagedObjectID!
        
        if cachedPhotos.isEmpty {
            id = (fetchedResultsController.object(at: indexPath) as! Photo).objectID
        } else {
            id = cachedPhotos[indexPath.item]?.objectID
        }
        
        if let id = id {
            getPhotoById(id: id) { (photo, error) in
                if let err = error {
                    print("Error getting photo: \(err)")
                } else {
                    if let photo = photo {
                        selectedPhotos = selectedPhotos.filter() {$0 != photo}
                    }
                }
            }
        }
        
        if selectedPhotos.isEmpty {
            setEditMode(edit: false)
        }

    }
}

// MARK: Flickr API

extension PhotoAlbumViewController {
    
    
    func getPhotoAsync(photoID: NSManagedObjectID, index: Int){
       print("Is Temporary ??? \(photoID.isTemporaryID)")
        
        var bgContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        bgContext.parent = self.stack.context
        //bgContext.persistentStoreCoordinator = self.stack.coordinator
        
        bgContext.perform {
           
                guard let url = URL(string: (self.results[index]["url_m"] as? String)!) else {
                    print("No url")
                    return
                }
                guard let imageData = NSData(contentsOf: url) else {
                    print("No image data")
                    return
                }
            
            do {
                let photo = try bgContext.existingObject(with: photoID)
                photo.setValue(imageData, forKey: "image")
                
                do {
                    try bgContext.save()
                } catch let err {
                    print("Error saving BG context: \(err)")
                }
                
            } catch let error {
                print("Error---->>>> \(error)")
            }
            
            performUIUpdatesOnMain(updates: { 
                self.collectionView.reloadData()
            })

            
//            self.stack.context.perform {
//                photo.setValue(imageData, forKey: "image")
//                do {
//                    try self.stack.context.save()
//                } catch let error{
//                    print("Error saving main context: \(error)")
//                }
//            }
            
            
        
        }
    }
    
        
        
 //       let queu = DispatchQueue(label: "getImages")
//        queu.async {
//            for (index, result) in self.results.enumerated() {
//                guard let url = URL(string: (result["url_m"] as? String)!) else {
//                    print("No url")
//                    return
//                }
//                guard let imageData = NSData(contentsOf: url) else {
//                    print("No image data")
//                    return
//                }
//                let indexPath = IndexPath(item: index, section: 0)
//                
//                guard let photo = self.fetchedResultsController.object(at: indexPath) as? NSManagedObject else {
//                    print("No photo")
//                    return
//                }
//                
//                photo.setValue(imageData, forKey: "image")
//                print("Saving Photo")
//            
//                performUIUpdatesOnMain {
//                    self.actionButton.isEnabled = false
//                }
//
//        }
//    }
        
    
    
    
    
    // MARK: Flickr API
    func getImagesFromFlickr(completion: @escaping (_ success: Bool) -> Void) {
        flickr.getPhotosByLocation(longitude: location.longitude, latitude: location.latitude, completionHandler: { (success: Bool, results: [[String: AnyObject]]?, meta: [String: Int]?,  error:String?) in
            if success {
                self.results = results!
                
                if let meta = meta {
                    if let savedMeta = self.meta {
                        print("------ Update Meta -------- ")
                        
                    } else {
                        print("Create new meta")
                        self.meta = Meta(pages: Int32(meta["pages"]!), page: Int32(meta["page"]!), pin: self.location, context: self.stack.context)
                        
                        for result in results! {
                            let newPhoto = Photo(image: nil, pin: self.location, meta: self.meta, context: self.stack.context)
                        
                        }
                        
                        do {
                            try self.stack.saveContext()
                            print("Results saved!!!")
                            try self.fetchedResultsController.performFetch()
                            print(self.fetchedResultsController.fetchedObjects?.count)
                        } catch let err {
                            print("Err----- \(err)")
                        }
                        
                         completion(true)
                    
                    }
                }
                
                DispatchQueue.main.async {
                    self.toggleLoadingState(loading: false)
                    self.collectionView.reloadData()

                }
            } else {
                completion(false)
            }
        })
        
    }
}

