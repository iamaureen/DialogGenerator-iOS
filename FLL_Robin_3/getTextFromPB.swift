//
//  getTextFromPB.swift
//  FLL_Robin_3
//
//  Created by HeklerLab on 10/24/17.
//  Copyright © 2017 HeklerLab. All rights reserved.
//

import Foundation

var textOfSpeech=""

func getTextFromPandorabot(_ result: String, completion: @escaping (_ fromPandorabot: String) -> ()) {
    
    print("sending to pb :: \(result)")
    
    let urlToRequest = "https://aiaas.pandorabots.com/talk/1409611535153/robinsocial"
    
    let url4 = URL(string: urlToRequest)!
    
    let session4 = URLSession.shared
    let request = NSMutableURLRequest(url: url4)
    request.httpMethod = "POST"
    request.cachePolicy = NSURLRequest.CachePolicy.reloadIgnoringCacheData
    //
    let paramString = "input=\(result)&user_key=7d387c332ebfa536b90b7820426ed63b" //setting value obtained from mysql database and get response from that
    //let paramString = "input=Set name ishrat&user_key=7d387c332ebfa536b90b7820426ed63b" //setting name
    request.httpBody = paramString.data(using: String.Encoding.utf8)
    let task = session4.dataTask(with: request as URLRequest) { (data, response, error) in
        guard let _: Data = data, let _: URLResponse = response, error == nil else {
            print("*****error")
            return
        }
        //let dataString = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)
        //print("*****This is the data from pandorabots: \(dataString)") //JSONSerialization
        
        
        if let jsonDict = (try? JSONSerialization.jsonObject(with: data!)) as? [String: Any] {
            //print("*****This is the data from pandorabots:\(jsonDict)")
            if let responses = jsonDict["responses"] as? [String]{
                for response in responses {
                    print("*****This is the data from pandorabots(in func): \(response)")
                    textOfSpeech = response
                    
                    
                    //post to db here user log??
                    completion(responses[0])
                    
                }
            }
            else{
                print("Unable to parse data")
            }
        }else{
            print("Unable to convert object recieved from pandorabot")
        }
        
        
    }
    
    task.resume()
    
}
