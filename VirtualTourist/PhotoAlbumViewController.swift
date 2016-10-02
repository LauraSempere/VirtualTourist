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

class PhotoAlbumViewController: UIViewController {

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var mapView: MKMapView!
    var location:Pin!
    let flickr = FlickrClient.sharedInstance()
    let stack = (UIApplication.shared.delegate as! AppDelegate).stack
    
    override func viewDidLoad() {
        super.viewDidLoad()

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
    
    func getSavedImages() {
        let fetchReq:NSFetchRequest<Photo> = Photo.fetchRequest()
        let pred = NSPredicate(format: "pin = %@", argumentArray: [location])
        fetchReq.predicate = pred
        do {
            let images = try stack.context.fetch(fetchReq)
            print("Photos for current Location: \(images)")
        } catch let error {
            print("Error getting images: \(error)")
        }
    }
    
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
