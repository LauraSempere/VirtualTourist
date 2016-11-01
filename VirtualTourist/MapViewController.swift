//
//  ViewController.swift
//  VirtualTourist
//
//  Created by Laura Scully on 1/10/2016.
//  Copyright © 2016 laura.sempere.com. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class MapViewController: UIViewController, MKMapViewDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    var longTapGesture:UILongPressGestureRecognizer!
    var editModde:Bool = false
    var context:NSManagedObjectContext!
    var bgContext:NSManagedObjectContext!
    var savedPins = [Pin]()
    
    override func viewDidLoad() {
        print(mapView.region)
        print("-----------")
        super.viewDidLoad()
        getAndDisplayPins()
        if let longitude = UserDefaults.standard.value(forKey: "longitude") as? CLLocationDegrees {
            if let latitude = UserDefaults.standard.value(forKey: "latitude") as? CLLocationDegrees {
                if let deltaLongitude = UserDefaults.standard.value(forKey: "deltaLongitude") as? CLLocationDegrees {
                    if let deltaLatitude = UserDefaults.standard.value(forKey: "deltaLatitude") as? CLLocationDegrees{
                        let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), span: MKCoordinateSpan(latitudeDelta: deltaLatitude, longitudeDelta: deltaLongitude))
                        mapView.setRegion(region, animated: true)
                        
                    }
                }
            }
        }
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Edit", style: UIBarButtonItemStyle.done, target: self, action: #selector(MapViewController.startEditing))
        
        longTapGesture = UILongPressGestureRecognizer(target: self, action: #selector(MapViewController.dropPin))
        longTapGesture.minimumPressDuration = 0.5
        mapView.addGestureRecognizer(longTapGesture)
        mapView.delegate = self
        
    }
    
    
    func startEditing() {
        editModde = true
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(MapViewController.finishEditing))
    }
    
    func finishEditing() {
        editModde = false
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Edit", style: UIBarButtonItemStyle.done, target: self, action: #selector(MapViewController.startEditing))
    }
    
    func dropPin(gestureRecognizer: UILongPressGestureRecognizer) {
        
        let tapPoint: CGPoint = gestureRecognizer.location(in: mapView)
        let touchMapCoordinate: CLLocationCoordinate2D = mapView.convert(tapPoint, toCoordinateFrom: mapView)
        
        if UIGestureRecognizerState.began == gestureRecognizer.state {
            let annotation = MKPointAnnotation()
            annotation.coordinate = touchMapCoordinate
            mapView.addAnnotation(annotation)
            
            let newPin = Pin(context: context)
            newPin.longitude = touchMapCoordinate.longitude
            newPin.latitude = touchMapCoordinate.latitude
            do {
                try context.save()
                print("Saving Pin to DB...")
            } catch {
                print("Error saving context to DB")
            }
            
        }
    }
    
    func displayPins() {
        var annotations = [MKPointAnnotation]()
        for pin in savedPins {
            let annotation = MKPointAnnotation()
            annotation.coordinate.longitude = pin.longitude
            annotation.coordinate.latitude = pin.latitude
            mapView.addAnnotation(annotation)
        }
    }
    
    func getAndDisplayPins() {
        let fetchReq:NSFetchRequest<Pin> = Pin.fetchRequest()
        
        do {
            let results = try context.fetch(fetchReq)
            savedPins = results
            displayPins()
        } catch let error as NSError {
            print("Error : \(error)")
        }
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        let currentLong:Double = mapView.region.center.longitude
        let currentLat:Double = mapView.region.center.latitude
        let deltaLong:Double = mapView.region.span.longitudeDelta
        let deltaLat:Double = mapView.region.span.latitudeDelta
        
        UserDefaults.standard.set(currentLong, forKey: "longitude")
        UserDefaults.standard.set(currentLat, forKey: "latitude")
        UserDefaults.standard.set(deltaLat, forKey: "deltaLatitude")
        UserDefaults.standard.set(deltaLong, forKey: "deltaLongitude")
       
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        print(mapView.center)
        print(mapView.region)
        let request:NSFetchRequest = Pin.fetchRequest()
        let longPredicate = NSPredicate(format: "longitude = %@", argumentArray: [Double((view.annotation?.coordinate.longitude)!)])
        let latPredicate = NSPredicate(format: "latitude = %@", argumentArray: [Double((view.annotation?.coordinate.latitude)!)])
        request.predicate = NSCompoundPredicate(type: .and, subpredicates: [longPredicate, latPredicate])
        var selectedPin:Pin!
        
        do {
            let results = try context.fetch(request)
            selectedPin = results[0]
            
        } catch let error {
            print("Error fetching request: \(error)")
        }
        
        if editModde {
            context.delete(selectedPin)
            do {
                try context.save()
                mapView.removeAnnotation(view.annotation!)
            } catch let error {
                print("Error saving Context -> \(error)")
            }
            
        } else {
            print("Navigate to detail view...")
            let photoAlbumVC = self.storyboard?.instantiateViewController(withIdentifier: "PhotoAlbumVC") as? PhotoAlbumViewController
            photoAlbumVC?.location = selectedPin
            photoAlbumVC?.context = context
            photoAlbumVC?.bgContext = bgContext
            self.navigationController?.pushViewController(photoAlbumVC!, animated: true)
            
        }
    }
    
}



