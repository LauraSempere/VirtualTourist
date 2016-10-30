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
    var blockOperations:[BlockOperation] = [BlockOperation]()
    var location:Pin!
    var meta:Meta!
    var photos:[Photo] = [Photo]()
    let flickr = FlickrClient.sharedInstance()
    
    var selectedPhotos:[Photo] = []
    var editMode:Bool = false
    
    //    var insertedIndexPaths: [IndexPath]!
    //    var deletedIndexPaths : [IndexPath]!
    //    var updatedIndexPaths : [IndexPath]!
    //
    
    var fetchedResultController:NSFetchedResultsController<Photo>!
    
    @IBAction func excuteAction(_ sender: AnyObject) {
        if editMode {
            print("Remove Selected Images")
            
        } else {
            print("Get new images from Flickr")
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //getPhotosForCurrentLocation()
        collectionView.dataSource = self
        collectionView.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        getPhotosForCurrentLocation()
        
        if (fetchedResultController.fetchedObjects?.count)! > 0 {
            toggleLoadingState(loading: false)
        } else {
            toggleLoadingState(loading: true)
            getPhotosFromFlickr()
        }
        

    }
    
    func getPhotosForCurrentLocation(){
        let request:NSFetchRequest<Photo> = Photo.fetchRequest()
        let predicate:NSPredicate = NSPredicate(format: "pin = %@", location)
        let sortDescriptor = NSSortDescriptor(key: "image", ascending: true)
        request.sortDescriptors = [sortDescriptor]
        request.predicate = predicate
        
        fetchedResultController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultController.delegate = self
        
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
    
    
    func showPhotos() {
        print("Job Done")
        print(photos)
        performUIUpdatesOnMain {
            self.toggleLoadingState(loading: false)
            self.collectionView.reloadData()
        }
    }
    
    func getPhotosFromFlickr() {
        self.context.performAndWait {
            self.flickr.getPhotosByLocation(longitude: self.location.longitude, latitude: self.location.latitude) { (success, results, meta, errorString) in
                if success {
                    guard let meta = meta else {return}
                    guard let results = results else {return}
                    var newMeta = Meta(context: self.context)
                    newMeta.page = Int32(meta["page"]!)
                    newMeta.pages = Int32(meta["pages"]!)
                    newMeta.pin = self.location
                    self.location.meta = newMeta
                    
                    
                    for result in results {
                        var newPhoto = Photo(context: self.context)
                        newPhoto.pin = self.location
                        newPhoto.meta = newMeta
                        self.photos.append(newPhoto)
                        self.photos.insert(newPhoto, at: 0)
                    }
                    
                    do {
                        try self.context.save()
                    } catch let error {
                        print("Error saving photos: \(error)")
                    }
                }
                
            }
        }
        
        showPhotos()
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
        
        
        
        if let savedImageData = fetchedResultController.object(at: indexPath).image {
            cell.image.image = UIImage(data: savedImageData as Data)
            cell.activityIndicator.stopAnimating()
            cell.activityIndicator.isHidden = true
        } else {
            cell.activityIndicator.startAnimating()
            cell.activityIndicator.isHidden = false
            cell.backgroundColor = UIColor.orange
        }
        return cell
    }
    
    
    // MARK NSFetchedResultsControllerDelegate
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        blockOperations = []
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            blockOperations.append(BlockOperation(block: {
                self.collectionView.insertItems(at: [newIndexPath!])
            }))
        case .delete:
            blockOperations.append(BlockOperation(block: {
                self.collectionView.insertItems(at: [indexPath!])
            }))
        case .update:
            blockOperations.append(BlockOperation(block: {
                self.collectionView.reloadItems(at: [indexPath!])
            }))
        case .move:
            blockOperations.append(BlockOperation(block: {
                self.collectionView.moveItem(at: indexPath!, to: newIndexPath!)
            }))
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

