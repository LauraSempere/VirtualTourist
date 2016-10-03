//
//  GCD.swift
//  VirtualTourist
//
//  Created by Laura Scully on 2/10/2016.
//  Copyright © 2016 laura.sempere.com. All rights reserved.
//


import Foundation

func performUIUpdatesOnMain(updates: @escaping () -> Void) {
    DispatchQueue.main.async {
        updates()
    }
}
