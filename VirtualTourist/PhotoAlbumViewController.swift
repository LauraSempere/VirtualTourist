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
    var location:Pin!
    var results:[[String:AnyObject]] = [[String:AnyObject]]()
    var photos:[Photo] = [Photo]()
    var cachedImages = [Int:UIImage]()
    let flickr = FlickrClient.sharedInstance()
    let stack = (UIApplication.shared.delegate as! AppDelegate).stack
    
    
    
    var fetchedResultsController: NSFetchedResultsController<Photo>? {
        didSet {
            fetchedResultsController?.delegate = self
            executeSearch()
            collectionView.reloadData()
        }
    }
//    required init?(coder aDecoder: NSCoder) {
//        super.init(coder: aDecoder)
//    }
//    
//    init(fetchedResultsController fc: NSFetchedResultsController<Photo>) {
//        fetchedResultsController = fc
//        super.init()
//    }
    
  
    
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
        collectionView.backgroundColor = UIColor.black

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        print("View Will Appear --------------- > \(location)")
        //getSavedImages()
        getImagesFromFlickr()
    }
    
    // MARK: CollectionView
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return results.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoAlbumCell", for: indexPath) as! PhotoAlbumCell
        cell.backgroundColor = UIColor.orange
        cell.activityIndicator.startAnimating()
        cell.image.image = UIImage(named: "placeholder")
        if let cachedImg = cachedImages[indexPath.item] {
            cell.image.image = cachedImg
        } else {
            getPhotoAsync(index: indexPath.item) { (image) in
                if let img = image {
                    cell.image.image = img
                    cell.activityIndicator.stopAnimating()
                    cell.activityIndicator.isHidden = true
                } else {
                    cell.activityIndicator.stopAnimating()
                    cell.activityIndicator.isHidden = true
                }
            }
        }
        
        return cell
    }

    
    // MARK: Core Data
    func getSavedImages() {
        let fetchReq:NSFetchRequest<Photo> = Photo.fetchRequest()
        let pred = NSPredicate(format: "pin = %@", argumentArray: [location])
        fetchReq.predicate = pred
        do {
            photos = try stack.context.fetch(fetchReq)
            print("Photos for current Location: \(photos)")
        } catch let error {
            print("Error getting images: \(error)")
        }
    }
    
    func getPhotoAsync(index: Int, completionHandler: @escaping (_ image:UIImage?) -> Void){
        DispatchQueue.global(qos: .userInteractive).async {
            if let url = URL(string: (self.results[index]["url_m"] as? String)!) {
                let imageData = NSData(contentsOf: url)
                let photo = Photo(image: imageData!, pin: self.location, context: self.stack.context)
                self.photos.append(photo)
                if let image = UIImage(data: imageData as! Data) {
                    self.cachedImages[index] = image
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
        flickr.getPhotosByLocation(longitude: location.longitude, latitude: location.latitude, completionHandler: { (success: Bool, results: [[String: AnyObject]]?, error:String?) in
            if success {
                self.results = results!
                DispatchQueue.main.async {
                    self.collectionView.reloadData()
                }
            }
        })
    
    }

}
