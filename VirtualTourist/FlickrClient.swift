//
//  FlickrClient.swift
//  VirtualTourist
//
//  Created by Laura Scully on 2/10/2016.
//  Copyright © 2016 laura.sempere.com. All rights reserved.
//

import Foundation

class FlickrClient:NSObject {
    
    var photosCount:Int = 0
    
    func flickrURLWithParams(params: [String: AnyObject]) -> URL {
        let components = NSURLComponents()
        components.scheme = Constants.Flickr.APIScheme
        components.host = Constants.Flickr.APIHost
        components.path = Constants.Flickr.APIPath
        
        var queryItems = [URLQueryItem]()
        
        for (k, v) in params {
            queryItems.append(URLQueryItem(name: k, value: "\(v)"))
        }
    
        components.queryItems = queryItems
        return components.url!
    }
    
    func getPhotosByLocation(longitude: Double, latitude: Double, completionHandler: @escaping (_ success: Bool, _ results: [[String: AnyObject]]?, _ errorString: String?) -> Void){
        let methodParameters: [String: String?] = [
            Constants.FlickrParameterKeys.BoundingBox: createBBox(longitude: longitude, latitude: latitude),
            Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey,
            Constants.FlickrParameterKeys.SafeSearch: Constants.FlickrParameterValues.UseSafeSearch,
            Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.MediumURL,
            Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.SearchMethod,
            Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat,
            Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback,
            Constants.FlickrParameterKeys.PerPage: "21",
            Constants.FlickrParameterKeys.Page: "1"]
        
        taskForGETMethod(params: methodParameters as [String : AnyObject]) {
            (results: [[String: AnyObject]]?, error: String?) in
            if let err = error {
               completionHandler(false, nil, err)
            } else {
                completionHandler(true, results, nil)
            }
            
        }
    
        
    }
    
    func taskForGETMethod(params:[String:AnyObject], completionHandler:@escaping (_ results:[[String: AnyObject]]?, _ error: String?) -> Void) -> URLSessionDataTask {
        let url = flickrURLWithParams(params: params)
        let session = URLSession.shared
        let request = MutableURLRequest(url: url)
        request.httpMethod = "GET"
        let task = session.dataTask(with: request as URLRequest) { (data, resp, error) in
            
            func sendError(error: String) {
                print(error)
                //let userInfo = [NSLocalizedDescriptionKey : error]
                completionHandler(nil, error)
            }
            
            guard(error == nil) else {
                sendError(error: "Network connection failed")
                return
            }
            
            guard let statusCode = (resp as? HTTPURLResponse)?.statusCode , statusCode >= 200 && statusCode <= 299 else {
                sendError(error: "Could not get data from the server")
                return
            }
            
            guard let data = data else {
                sendError(error: "No data was returned from the Server")
                return
            }
            
            self.convertDataWithCompletionHandler(data: data, completionHandlerForConvertData: { (result: AnyObject?, error: Error?) in
                guard (error == nil) else {
                    sendError(error: (error?.localizedDescription)!)
                    return
                }
                print("Result ======= >>>>>>> \(result)")
                guard let result = result else {
                    sendError(error: "No results were deserialized")
                    return
                }
                guard let OKstat = result[Constants.FlickrResponseKeys.Status] as? String, OKstat == Constants.FlickrResponseValues.OKStatus else {
                    sendError(error: "No images were received from Flickr")
                    return
                }
                guard let photos = result["photos"] as? [String: AnyObject] else {
                    sendError(error: "No photos were received from Flickr")
                    return
                }
                
                guard let photoCollection = photos["photo"] as? [[String: AnyObject]] else {
                    sendError(error: "No Photo Collection received from Flickr")
                    return
                }
                self.photosCount = photoCollection.count
                
                completionHandler(photoCollection, nil)
            })
            
        }
        task.resume()
        return task
    }
    
    
    // given raw JSON, return a usable Foundation object
    private func convertDataWithCompletionHandler(data: Data, completionHandlerForConvertData: (_ result: AnyObject?, _ error: Error?) -> Void) {
        
        var parsedResult: AnyObject!
        do {
            parsedResult = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? AnyObject
        } catch {
            let userInfo = [NSLocalizedDescriptionKey : "Could not parse the data as JSON: '\(data)'"]
            completionHandlerForConvertData(nil, NSError(domain: "convertDataWithCompletionHandler", code: 1, userInfo: userInfo))
        }
        
        completionHandlerForConvertData(parsedResult, nil)
    }
    
    private func createBBox(longitude: Double, latitude:Double) -> String{
            let minLon = max((longitude - Constants.Flickr.SearchBBoxHalfWidth), Constants.Flickr.SearchLonRange.0)
            let minLat = max((latitude - Constants.Flickr.SearchBBoxHalfHeight), Constants.Flickr.SearchLatRange.0)
            let maxLon = min((longitude + Constants.Flickr.SearchBBoxHalfWidth) , Constants.Flickr.SearchLonRange.1)
            let maxLat = min((latitude + Constants.Flickr.SearchBBoxHalfHeight), Constants.Flickr.SearchLatRange.1)
            return "\(minLon),\(minLat),\(maxLon),\(maxLat)"
        
    }
    
    class func sharedInstance() -> FlickrClient {
        struct Singleton {
            static var sharedInstance = FlickrClient()
        }
        return Singleton.sharedInstance
    }

    
}

