//
//  getInfoFromDatabase.swift
//  FLL_Robin_3
//
//  Created by HeklerLab on 10/24/17.
//  Copyright © 2017 HeklerLab. All rights reserved.
//

import Foundation

    //added completion handler to return data from the database
    func getTextOfSpeech(completion: @escaping (_ feedback_from_module: String) -> ()) {
        //let URL_GET = "http://192.168.1.7/api/product/read.php" //home
        let URL_GET = "http://10.143.8.55/api/product/read.php" //lab
        //let URL_GET = "http://localhost:/api/product/read.php" //mac localhost

        let requestURL = URL(string: URL_GET)
        var feedback_from_module=""
        //create URL request
        var request = URLRequest(url: requestURL!)
        //setting the method to GET
        request.httpMethod = "GET"
        //creating a task to send the get request
        let task = URLSession.shared.dataTask(with: request){
            (data, response, error) in
            //if data is nil or no
            if(data != nil){
                print("data is not empty :: \(data)")
            }else{
                print("data is empty")
            }
            //exiting if there is some error
            if error != nil{
                print("error is \(error)")
                return;
            }
            do {
                let parsedData = try JSONSerialization.jsonObject(with: data!) as! [String:AnyObject]
                //print("after parsing data \(parsedData)")
                let userData = parsedData["records"] as! [AnyObject]
                for user in userData{
                    feedback_from_module = user["errormsg"] as! String
                    print("feedback :: \(feedback_from_module)")

                }

                completion(feedback_from_module)
                // print(feedback_from_module);
            } catch {
                print("Error deserializing JSON: \(error)")
            }
        }
        //executing the task
        task.resume()

    }
