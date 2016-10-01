//
//  ViewController.swift
//  VirtualTourist
//
//  Created by Laura Scully on 1/10/2016.
//  Copyright © 2016 laura.sempere.com. All rights reserved.
//

import UIKit
import MapKit

class MapViewController: UIViewController, MKMapViewDelegate {
   
    @IBOutlet weak var mapView: MKMapView!
    var longTapGesture:UILongPressGestureRecognizer!
    var editModde:Bool = false

    
    override func viewDidLoad() {
        super.viewDidLoad()
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
            let pin = MKPointAnnotation()
            pin.coordinate = touchMapCoordinate
            mapView.addAnnotation(pin)
        }
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        print("Selected Pin :")
        print(view.annotation?.coordinate.latitude)
        if editModde {
            mapView.removeAnnotation(view.annotation!)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

