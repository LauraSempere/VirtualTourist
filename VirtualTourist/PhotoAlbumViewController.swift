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

class PhotoAlbumViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var mapView: MKMapView!
    var location:Pin!
    var photos:[Photo] = [Photo]()
    let flickr = FlickrClient.sharedInstance()
    let stack = (UIApplication.shared.delegate as! AppDelegate).stack
    
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
        getSavedImages()
    }
    
    // MARK: CollectionView
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 5
        //return photos.count
    }
    
//    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
//        return 1
//    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoAlbumCell", for: indexPath) as! PhotoAlbumCell
        print("------ Cell ------ \(cell)")
        cell.activityIndicator.startAnimating()
        cell.backgroundColor = UIColor.orange
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
    
    // MARK: Flickr API
    func getImagesFromFlickr() {
        flickr.getPhotosByLocation(longitude: location.longitude, latitude: location.latitude, completionHandler: { (success: Bool, results: [[String: AnyObject]]?, error:String?) in
            if success {
                print("Success!!")
                for result in results! {
                    do {
                        let url = URL(string: result["url_m"] as! String)
                        let imageFromURL = try NSData(contentsOf: url!)
                        Photo(image: imageFromURL!, pin: self.location, context: self.stack.context)
                        
                    } catch let err {
                        print("Error creating image Data from url: \(err)")
                    }
                }
                
            }
        })
    
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
