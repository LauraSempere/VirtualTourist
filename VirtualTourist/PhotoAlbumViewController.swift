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
    let flickr = FlickrClient.sharedInstance()
    var photoResults: [[String:AnyObject]] = []
    
    var selectedPhotos:[NSManagedObjectID] = []
    var editMode:Bool = false
    var fetchedResultController:NSFetchedResultsController<Photo>!
    
    @IBAction func excuteAction(_ sender: AnyObject) {
        if editMode {
            self.bgContext.performAndWait {
                for selectedID in self.selectedPhotos {
                    do {
                        let photo = try self.bgContext.existingObject(with: selectedID)
                        self.bgContext.delete(photo)
                    } catch let err {
                        print("Err finding selected photo in bgContext: \(err)")
                    }
                }
                do {
                    try self.bgContext.save()
                    
                } catch let error {
                    print("Error removing selected photos: \(error)")
                }
            }
            performUIUpdatesOnMain {
                self.toggleEditMode(edit: false)
            }
            
        } else {
            toggleLoadingState(loading: true)
            actionButton.isEnabled = false
            removeAndGetNewPhotos()
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let request:NSFetchRequest<Photo> = Photo.fetchRequest()
        let predicate:NSPredicate = NSPredicate(format: "pin = %@", location)
        let sortDescriptor = NSSortDescriptor(key: "created", ascending: true)
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
        let center = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 25.0, longitudeDelta: 25.0))
        mapView.setRegion(region, animated: true)
        
        
        getPhotosForCurrentLocation()
        
        if (fetchedResultController.fetchedObjects?.count)! > 0 {
            toggleLoadingState(loading: false)
        } else {
            toggleLoadingState(loading: true)
            actionButton.isEnabled = false
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
            actionButton.title = "Get New Images"
        }
    }
    
    func getImagesForPhotos() {
        for (index, photoResult) in photoResults.enumerated() {
            let photoID = fetchedResultController.object(at: IndexPath(item: index, section: 0)).objectID
            bgContext.performAndWait {
                do {
                    let photo = try self.bgContext.existingObject(with: photoID) as! Photo
                    guard let urlString = photoResult["url_m"] as? String else {return}
                    guard let url = URL(string: urlString) else {return}
                    guard let imageData = NSData(contentsOf: url) else {return}
                    photo.image = imageData
                    try self.bgContext.save()
                    
                } catch let error {
                    print("Error getting photo: \(error)")
                }
            }
            
        }
        performUIUpdatesOnMain {
            self.actionButton.isEnabled = true
        }
    }
    
    func removeAndGetNewPhotos() {
        var photosID:[NSManagedObjectID] = []
        for photo in fetchedResultController.fetchedObjects! {
            photosID.append(photo.objectID)
        }
        bgContext.performAndWait {
            for photoID in photosID {
                do {
                    let photo = try self.bgContext.existingObject(with: photoID)
                    self.bgContext.delete(photo)
                } catch let err {
                    print("Err getting photo: \(err)")
                }
            }
            do {
                try self.bgContext.save()
                
            } catch let err {
                print("Deleting objetcs error: \(err)")
            }
        }
        getPhotosFromFlickr(locID: location.objectID)
    }
    
    
    func getPhotosFromFlickr(locID:NSManagedObjectID) {
        self.flickr.getPhotosForLocation(location: location, meta: meta) { (success, results, meta, errorString) in
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
                        } catch let err {
                            print("Error removing meta: \(err)")
                        }
                    }
                }
                
                self.bgContext.performAndWait {
                    guard let meta = meta else {return}
                    guard let results = results else {return}
                    self.photoResults = results
                    var newMeta = Meta(context: self.bgContext)
                    newMeta.page = Int32(meta["page"]!)
                    newMeta.pages = Int32(meta["pages"]!)
                    self.meta = newMeta
                    
                    newMeta.pin = loc
                    loc.meta = newMeta
                    
                    
                    for result in results {
                        var newPhoto = Photo(context: self.bgContext)
                        newPhoto.created = NSDate()
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
                self.context.performAndWait {
                    performUIUpdatesOnMain {
                        self.toggleLoadingState(loading: false)
                    }
                }
                
                self.getImagesForPhotos()
                
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
        cell.image.image = UIImage(named: "placeholder")
        configureCell(cell: cell, indexPath: indexPath)
        return cell
    }
    
    func  configureCell(cell: PhotoAlbumCell, indexPath: IndexPath) {
        if let savedImageData = fetchedResultController.object(at: indexPath).image {
            cell.image.isHidden = false
            cell.image.image = UIImage(data: savedImageData as Data)
            cell.activityIndicator.stopAnimating()
            cell.activityIndicator.isHidden = true
        } else {
            cell.activityIndicator.startAnimating()
            cell.activityIndicator.isHidden = false
            cell.image.isHidden = false
            cell.backgroundColor = UIColor.orange
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if !editMode {
            toggleEditMode(edit: true)
        }
        
        let selectedPhoto = fetchedResultController.object(at: indexPath)
        selectedPhotos.append(selectedPhoto.objectID)
        let cell = collectionView.cellForItem(at: indexPath) as! PhotoAlbumCell
        cell.backgroundColor = UIColor.cyan
        cell.alpha = 0.4
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        let selectedPhoto = fetchedResultController.object(at: indexPath)
        selectedPhotos = selectedPhotos.filter(){$0 != selectedPhoto.objectID}
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
            break
            
        case .update:
            let op = BlockOperation {
                if let indexPath = indexPath, let cell = self.collectionView.cellForItem(at: indexPath) as? PhotoAlbumCell {
                    self.configureCell(cell: cell, indexPath: indexPath)
                }
            }
            blockOperations.append(op)
            break
            
        case .move:
            let op = BlockOperation {
                if let indexPath = indexPath {
                    self.collectionView.deleteItems(at: [indexPath])
                }
                if let newIndexPath = newIndexPath {
                    self.collectionView.insertItems(at: [newIndexPath])
                }
            }
            blockOperations.append(op)
            break
            
        case .delete:
            let op = BlockOperation {
                if let indexPath = indexPath {
                    self.collectionView.deleteItems(at: [indexPath])
                }
            }
            blockOperations.append(op)
            break
            
        default: break
        
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        collectionView.performBatchUpdates({
            for operation in self.blockOperations {
                operation.start()
            }
        }) { (finished) in
            self.blockOperations.removeAll(keepingCapacity: false)
        }
    }
    
}

