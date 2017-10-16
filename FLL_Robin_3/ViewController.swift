//
//  ViewController.swift
//  FLL_Robin_3
//
//

/* Current setup: When user pushes button, we download text from SQL. When 'movement stop'
 * is detected, convert text to speech and play text to speech. Enable button to start talking.
 * When the user pushes the button speech recognition starts, trigger pandorabot response when we get their speech to text.
 * They have to push the button to stop. Open questions...
 *      - Should we create a websocket to always listen for the latest write to the database?
 *      - How to make call to the Pandorabot API? See link below
 *      - How to cease motion monitoring? Buggy
 *      - best method for student to interact with microphone? Currently button touch screen - rsearch speech API
 *
 * PENDING TO-DOs:
 *  (1) Fix speech synthesis thread issue (see comments below - maybe post on stack overflow) - done
 *  (2) Add SQL call to function getTextOfSpeech() - https://www.raywenderlich.com/123579/sqlite-tutorial-swift & http://codewithchris.com/iphone-app-connect-to-mysql-database/ ; done
 *  (3) Setup call to Pandorabot API under return of transcript from function 'Start Recording' - should be able to use simple REST API calls to the Pandorabot API. Examples of calls with ios @ https://grokswift.com/simple-rest-with-swift/
 *  (4) Fix bug with the motion - doesn't always stop when the phone has stopped and sometimes stops earlier
 *  (5) Generate pretty waveform for when Robin is speaking (use pod? like maybe https://github.com/fulldecent/FDWaveformView or https://github.com/stefanceriu/SCSiriWaveformView ???)
 */

/* ISSUE: Currently the speech synthesis is called when the accelerometer detects a motion has stopped. Its called by adding it to the main operation queue. Problem is, it doesn't stop executing it. I think the way I'm triggering stuff to happen on 'motion stop detected' isn't right or there's a better way to do the multi-threading. Secondly, I wanted to turn accelerometer updates OFF when motion stop is detected. However...that's not happening either. All of this starts at line 176
 
 Getting added to the queue multiple times
 
 google : ios accelerometer motion manager + operationqueue ios swift 3,
 */

import UIKit
import AVFoundation
import CoreMotion
import Speech



class ViewController: UIViewController, SFSpeechRecognizerDelegate{
    
    // Outlet variables: speaking is a text field that indicates when the robot should be speaking
    // Start button is to trigger the monitoring of motion
    @IBOutlet weak var speaking: UITextField!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var TalkToRobinButton: UIButton!
    
    // Instance Variables
    var audioPlayer = AVAudioPlayer()
    let motionManager = CMMotionManager()
    
    // Movement variables
    var lastx = 1.0
    var lasty = 1.0
    var lastz = 1.0
    var lastTenAngles = Array(repeating: 0.0, count: 10)
    var index = 0
    var counter = 0
    var firstTime = true
    var movementDiff = 0.0
    var diffFromMean = 0.0
    var movingStarted = false
    var databasePath:String!
    
    // Text to speech variables
    let synth = AVSpeechSynthesizer()
    var myUtterance = AVSpeechUtterance(string: "")
    var textOfSpeech = ""
    var fromPandorabot = ""
    
    // Speech recognition variables
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    
    // When application first starts
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Get user permission to use microphone
        TalkToRobinButton.isEnabled = false  //2
        
        speechRecognizer?.delegate = self  //3
        
        
        SFSpeechRecognizer.requestAuthorization { (authStatus) in  //4
            //https://developer.apple.com/reference/foundation/operationqueue
            var isButtonEnabled = false
            
            switch authStatus {  //5
            case .authorized:
                isButtonEnabled = true
                //print("isButtonEnabled");
                
            case .denied:
                isButtonEnabled = false
                //print("User denied access to speech recognition")
                
            case .restricted:
                isButtonEnabled = false
                //print("Speech recognition restricted on this device")
                
            case .notDetermined:
                isButtonEnabled = false
                // print("Speech recognition not yet authorized")
            }
            
            OperationQueue.main.addOperation() {
                //print("inside oq viewDidLoad() \(self.counter)")
                self.TalkToRobinButton.isEnabled = isButtonEnabled
                self.TalkToRobinButton.isHidden = true
            }
        }
        //end of SFSpeechRecognizer.requestAuthorization
        
        /* This section is the original play waveform - will convert text to speech in app so no longer playing waveform
         let speech = Bundle.main.path(forResource: "Waveform_1", ofType: "mp3")
         do {
         audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: speech! ))
         try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryAmbient)
         try AVAudioSession.sharedInstance().setActive(true)
         }
         catch{
         print(error)
         }
         */
    }
    
    // Action Button: When user clicks on the button, we (1) download text, (2) convert text to speech, (3) begin tracking movement and (4) play the audio when movement ceases
    @IBAction func startButtonClick(_ sender: UIButton) {
        speaking.text = ""                                       // robot not speaking so speaking field is blank
        
        //     textOfSpeech = getTextOfSpeech()                      // get the text to speech
        
        getTextOfSpeech(completion: {result in
            print("returned from func speak:: \(result)")
            self.textOfSpeech = result
            self.fromPandorabot = result
            
            //send this to pandorabot and get what to say
            
            /*let urlToRequest = "https://aiaas.pandorabots.com/talk/1409611535153/robinsocial"
             
             let url4 = URL(string: urlToRequest)!
             
             let session4 = URLSession.shared
             let request = NSMutableURLRequest(url: url4)
             request.httpMethod = "POST"
             request.cachePolicy = NSURLRequest.CachePolicy.reloadIgnoringCacheData
             //
             //let paramString = "input=\(result)&user_key=7d387c332ebfa536b90b7820426ed63b" //setting value obtained from mysql database and get response from that
             let paramString = "input=Set name ishrat&user_key=7d387c332ebfa536b90b7820426ed63b" //setting name
             request.httpBody = paramString.data(using: String.Encoding.utf8)
             let task = session4.dataTask(with: request as URLRequest) { (data, response, error) in
             guard let _: Data = data, let _: URLResponse = response, error == nil else {
             print("*****error")
             return
             }
             //                let dataString = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)
             //                print("*****This is the data from pandorabots: \(dataString)") //JSONSerialization
             
             
             if let jsonDict = (try? JSONSerialization.jsonObject(with: data!)) as? [String: Any] {
             //print("*****This is the data from pandorabots:\(jsonDict)")
             if let responses = jsonDict["responses"] as? [String]{
             for response in responses {
             print("*****This is the data from pandorabots: \(response)")
             self.textOfSpeech = response
             //post to db here??
             }
             }
             else{
             print("Unable to parse data")
             }
             }else{
             print("Unable to convert object recieved from pandorabot")
             }
             
             
             }
             
             //TODO: extract the response part - done
             //TODO: save result and response both to user log database
             //TODO: convert response to speech - done
             //TODO: make it conversational
             //TODO: make it a functional call with a parameter result
             
             task.resume()*/
            
        })
        
        print("speak this :: \(fromPandorabot)")
        
        // Comment this out once if it works
        //self.synth.speak(self.myUtterance)
        
        //COMMENTING OUT FOR TESTING SPEECH RECOGNITION - add back once confirm speech recognition works
        
        motionManager.accelerometerUpdateInterval = 0.03         // Motion manager properties - update every 0.03 seconds
        let queue = OperationQueue()
        
        motionManager.startAccelerometerUpdates(to: queue) {    // Start accelerometer
            (data, error) in
            
            self.outputAccelerationData(acceleration: (data?.acceleration)!)  // enable TalkToRobin button
            
        }
        
        
        // Comment this out once it works
        //TalkToRobinButton.isHidden = false
        
    }
    
    
    // Ths function retrieves the acceleration data and will play audio when motion stop is detected
    func outputAccelerationData(acceleration: CMAcceleration){
        // First time movement is detected, set prior angles
        if firstTime {
            lastx = acceleration.x
            lasty = acceleration.y
            lastz = acceleration.z
            firstTime = false
        }
        else {
            
            // Option (1) - Calculating angle differences - not using this to detect movement stop
            let numerator = (lastx * acceleration.x) + (lasty * acceleration.y) + (lastz * acceleration.z)
            let denominator = sqrt(pow(lastx, 2.0)+pow(lasty,2.0)+pow(lastz,2))*sqrt(pow(acceleration.x, 2.0)+pow(acceleration.y,2.0)+pow(acceleration.z,2))
            let movementAngleAdv = cos(numerator/denominator)
            lastTenAngles[index] = movementAngleAdv
            diffFromMean = diffFromMean(angles: self.lastTenAngles)
            index+=1
            if index > 9 {
                index = 0
            }
            
            // Option (2) using differences between current x and prior x - not using this either
            movementDiff = abs(acceleration.x - lastx)
            
            // Option (3) calculate based on current value of x - using this option. If value of x is less than 0.1 for more than 15 counts (.45 seconds) then movement has stopped
            if (acceleration.x >= 0.1){
                movingStarted = true
                counter = 0
            }
            else if (movingStarted){
                if (counter > 15){
                    OperationQueue.main.addOperation {
                        //print("inside oq if(counter>15) counter value:: \(self.counter)")
                        self.counter=0 //here it works fine, why?
                        
                        //TODO: get data from pandorabot to speak
                        self.getTextFromPandorabot(completion: {result in
                            print("returned from func speak:: \(result)")
                            self.textOfSpeech = result
                            print("*****This is the data from pandorabots (here): \(self.textOfSpeech)")
                            
                            // Motion stop detected so play speech and enable talk
                            self.speaking.text = "Play Audio!"
                            self.myUtterance = AVSpeechUtterance(string: self.textOfSpeech)
                            self.myUtterance.rate = 0.4
                            print("I am here to speak :: \(self.textOfSpeech)")
                            self.synth.speak(self.myUtterance)
                            self.TalkToRobinButton.isHidden = false
                            
                        })
                        
//                        // Motion stop detected so play speech and enable talk
//                        self.speaking.text = "Play Audio!"
//                        self.myUtterance = AVSpeechUtterance(string: self.textOfSpeech)
//                        self.myUtterance.rate = 0.4
//                        print("I am here to speak :: \(self.textOfSpeech)")
//                        self.synth.speak(self.myUtterance)
//                        self.TalkToRobinButton.isHidden = false
                        
                        // Cease movement and reset tracking variables
                        self.movingStarted = false
                        self.motionManager.stopAccelerometerUpdates()
                        
                        //self.audioPlayer.play()
                        //self.counter=0 //if counter value set to 0 here, it does not work properly
                        
                    }
                }
                counter += 1
            }
            else {
                
                counter = 0
            }
            
            lastx = acceleration.x
            lasty = acceleration.y
            lastz = acceleration.z
        }
        
        
    }
    
    // ------- CURRENTLY NOT USING ---------
    // This function calculates the difference in distance from the past ten recorded angles - if it is within a certain amount, movement will be considered to have 'stopped'
    func diffFromMean(angles: [Double]) -> Double {
        var answer = 0.0
        var sum = 0.0
        for value in angles[1..<angles.count] {
            sum = sum+value
        }
        let average = sum/Double(angles.count)
        for value in angles[1..<angles.count] {
            answer = answer + (value - average)
        }
        
        return answer/Double(angles.count)
    }
    
    
    
    //added completion handler to return data from the database
    func getTextOfSpeech(completion: @escaping (_ feedback_from_module: String) -> ()) {
        let URL_GET = "http://192.168.1.7/api/product/read.php" //homes
        //let URL_GET = "http://10.143.10.102/api/product/read.php" //lab
        
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
    
    //completion: @escaping (_ fromPandorabot: String) -> ()
    
    func getTextFromPandorabot(completion: @escaping (_ fromPandorabot: String) -> ()) {
        
        print("getTextFromPandorabot")
        
        let urlToRequest = "https://aiaas.pandorabots.com/talk/1409611535153/robinsocial"
        
        let url4 = URL(string: urlToRequest)!
        
        let session4 = URLSession.shared
        let request = NSMutableURLRequest(url: url4)
        request.httpMethod = "POST"
        request.cachePolicy = NSURLRequest.CachePolicy.reloadIgnoringCacheData
        //
        //let paramString = "input=\(result)&user_key=7d387c332ebfa536b90b7820426ed63b" //setting value obtained from mysql database and get response from that
        let paramString = "input=Set name ishrat&user_key=7d387c332ebfa536b90b7820426ed63b" //setting name
        request.httpBody = paramString.data(using: String.Encoding.utf8)
        let task = session4.dataTask(with: request as URLRequest) { (data, response, error) in
            guard let _: Data = data, let _: URLResponse = response, error == nil else {
                print("*****error")
                return
            }
            //                let dataString = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)
            //                print("*****This is the data from pandorabots: \(dataString)") //JSONSerialization
            
            
            if let jsonDict = (try? JSONSerialization.jsonObject(with: data!)) as? [String: Any] {
                //print("*****This is the data from pandorabots:\(jsonDict)")
                if let responses = jsonDict["responses"] as? [String]{
                    for response in responses {
                        print("*****This is the data from pandorabots: \(response)")
                        self.textOfSpeech = response
                       

                        //post to db here??
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
        
        //TODO: extract the response part - done
        //TODO: save result and response both to user log database
        //TODO: convert response to speech - done
        //TODO: make it conversational
        //TODO: make it a functional call with a parameter result
        //TODO: add completion handler - done
        
        task.resume()
        
    }
    
    
    @IBAction func TalkToRobinClick(_ sender: UIButton) {
        
        motionManager.stopAccelerometerUpdates()
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            TalkToRobinButton.isEnabled = false
            TalkToRobinButton.setTitle("Start Talking", for: .normal)
        } else {
            startRecording()
            TalkToRobinButton.setTitle("Stop Talking", for: .normal)
        }
    }
    
    
    func startRecording(){
        
        
        
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSessionCategoryRecord)
            try audioSession.setMode(AVAudioSessionModeMeasurement)
            try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        } catch {
            print("audioSession properties weren't set because of an error.")
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let inputNode = audioEngine.inputNode else {
            fatalError("Audio engine has no input node")
        }
        
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in
            
            var isFinal = false
            
            if result != nil {
                
                //setting textfield with the speech
                self.speaking.text = result?.bestTranscription.formattedString
                isFinal = (result?.isFinal)!
                print("captured speech :: \(self.speaking.text)")
                
                // ******** CALL PANDORABOT API FROM HERE???? Get text of response and then set myutterance and play synthesis function
                
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                self.TalkToRobinButton.isEnabled = true
            }
        })
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            print("audioEngine couldn't start because of an error.")
        }
        
        speaking.text = "Say something, I'm listening!"
    }
    
    
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            TalkToRobinButton.isEnabled = true
        } else {
            TalkToRobinButton.isEnabled = false
        }
    }
    
    // Default function
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}

