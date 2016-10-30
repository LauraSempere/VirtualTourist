//
//  Int+Extension.swift
//  VirtualTourist
//
//  Created by Laura Scully on 30/10/2016.
//  Copyright © 2016 laura.sempere.com. All rights reserved.
//

import Foundation

extension Int {
    init(random range: Range<Int>) {
        
        let offset: Int
        if range.lowerBound < 0 {
            offset = abs(range.lowerBound)
        } else {
            offset = 0
        }
        
        let min = UInt32(range.lowerBound + offset)
        let max = UInt32(range.upperBound   + offset)
        
        self = Int(min + arc4random_uniform(max - min)) - offset
    }
}
