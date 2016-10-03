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
    var photos:[Photo] = [Photo]()
    var meta:Meta!
    var cachedPhotos = [Int: Photo]()
    let flickr = FlickrClient.sharedInstance()
    let stack = (UIApplication.shared.delegate as! AppDelegate).stack
    var selectedPhotos:[Photo] = []
    var editMode:Bool = false
    
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
    
    
    var fetchedResultsController: NSFetchedResultsController<Photo>? {
        didSet {
            fetchedResultsController?.delegate = self
            executeSearch()
            collectionView.reloadData()
        }
    }
    
    
    func executeSearch() {
        if let fc = fetchedResultsController {
            do {
                try fc.performFetch()
            } catch let error {
                print("Error fetching data: \(error)")
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.allowsMultipleSelection = true

        // Do any additional setup after loading the view.
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
                    getImagesFromFlickr()
                } else {
                    self.toggleLoadingState(loading: false)
                    print("Photos form DB")
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
        let fetchReq:NSFetchRequest<Photo> = Photo.fetchRequest()
        let pred = NSPredicate(format: "pin = %@", argumentArray: [location])
        fetchReq.predicate = pred
        do {
            photos = try stack.context.fetch(fetchReq)
            completionHandler(photos, nil)
            print("Photos for current Location: \(photos)")
        } catch let error {
            completionHandler(nil, error as Error?)
            print("Error getting images: \(error)")
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
    
    override func viewWillDisappear(_ animated: Bool) {
        do {
            try stack.context.save()
            print("Context saved successfuly !!")
        } catch let error {
            print("Error saving context on view will desapear : \(error)")
            
        }
    }
}


// MARK: CollectionView Data Source and Delegate
extension PhotoAlbumViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    // MARK: CollectionView
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if photos.isEmpty {
            return results.count
        } else {
            return photos.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoAlbumCell", for: indexPath) as! PhotoAlbumCell
        cell.backgroundColor = UIColor.lightGray
        cell.activityIndicator.startAnimating()
        cell.image.image = UIImage(named: "placeholder")
        
        if photos.isEmpty{
            
            if let cachedPhoto = cachedPhotos[indexPath.item] {
                cell.image.image = UIImage(data: cachedPhoto.image as! Data)
            } else {
                getPhotoAsync(index: indexPath.item) { (image) in
                    if let img = image {
                        cell.image.image = img
                    }
                    cell.activityIndicator.stopAnimating()
                    cell.activityIndicator.isHidden = true
                }
            }
            
        } else {
            cell.image.image = UIImage(data: photos[indexPath.item].image as! Data)
            cell.activityIndicator.stopAnimating()
            cell.activityIndicator.isHidden = true
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath) as! PhotoAlbumCell
        if !editMode {
            setEditMode(edit: true)
        }
       
        var id:NSManagedObjectID!
        
        if cachedPhotos.isEmpty {
            id = photos[indexPath.item].objectID
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
            id = photos[indexPath.item].objectID
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
    func getPhotoAsync(index: Int, completionHandler: @escaping (_ image:UIImage?) -> Void){
        DispatchQueue.global(qos: .userInteractive).async {
            if let url = URL(string: (self.results[index]["url_m"] as? String)!) {
                
                let imageData = NSData(contentsOf: url)
                let photo =  Photo(image: imageData!, pin: self.location, meta: self.meta, context: self.stack.context)
                self.cachedPhotos[index] = photo
               
                if let image = UIImage(data: imageData as! Data) {
                    DispatchQueue.main.async {
                        completionHandler(image)
                    }
                } else {
                    DispatchQueue.main.async {
                        completionHandler(nil)
                    }
                }
            }
            
        }
    }
    
    // MARK: Flickr API
    func getImagesFromFlickr() {
        flickr.getPhotosByLocation(longitude: location.longitude, latitude: location.latitude, completionHandler: { (success: Bool, results: [[String: AnyObject]]?, meta: [String: Int]?,  error:String?) in
            if success {
                self.results = results!
                DispatchQueue.main.async {
                    self.toggleLoadingState(loading: false)
                    self.collectionView.reloadData()
                    if let meta = meta {
                        if let savedMeta = self.meta {
                            print("------ Update Meta -------- ")
                            
                        } else {
                            self.meta = Meta(pages: Int32(meta["pages"]!), page: Int32(meta["page"]!), pin: self.location, context: self.stack.context)
                            do {
                                try self.stack.saveContext()
                                print("Meta saved successfully!!!")
                            } catch let err {
                                print("Error saving stack")
                            }
                        }
                        
                    }

                }
            }
        })
        
    }
}
