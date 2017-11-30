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
    var movingStarted = false
    
    // Text to speech variables
    let synth = AVSpeechSynthesizer()
    var myUtterance = AVSpeechUtterance(string: "")
    var textOfSpeech = ""
    var sendToPandorabot = ""
    
    // Speech recognition variables
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    
    // When application first starts
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // only 'try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord)' causes the voice to be very low. so
            //the following line is used, source: https://stackoverflow.com/questions/36115497/avaudioengine-low-volume
            try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with:AVAudioSessionCategoryOptions.defaultToSpeaker)
            try audioSession.setMode(AVAudioSessionModeMeasurement)
            
        } catch {
            print("audioSession properties weren't set because of an error.")
        }
        
        
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
        
        print("start button clicked")
        speaking.text = ""                                       // robot not speaking so speaking field is blank
        
        //        getTextOfSpeech(completion: {result in
        //            print("returned from mysql db, send value to pb :: \(result)")
        //            self.textOfSpeech = result
        //            self.sendToPandorabot = result
        //
        //
        //        })
        
        self.textOfSpeech = "I cannot do this"
        self.sendToPandorabot = "I cannot do this"
        
        motionManager.accelerometerUpdateInterval = 0.03         // Motion manager properties - update every 0.03 seconds
        
        let queue = OperationQueue()
        
        //starting updates to push data, the handler closure will be called at frequency given by the update interval
        //ref: http://nshipster.com/cmdevicemotion/
        
        motionManager.startAccelerometerUpdates(to: queue) {    // Start accelerometer
            (data, error) in
            
            self.outputAccelerationData(acceleration: (data?.acceleration)!)
        }
        
    }
    
    
    // Ths function retrieves the acceleration data and will play audio when motion stop is detected
    func outputAccelerationData(acceleration: CMAcceleration){
        
        print("inside outputAccelerationData method")
        // First time movement is detected, set prior angles
        if firstTime {
            lastx = acceleration.x
            lasty = acceleration.y
            lastz = acceleration.z
            firstTime = false
        }
        else {
            
            // calculate based on current value of x - using this option. If value of x is less than 0.1 for more than 15 counts (.45 seconds) then movement has stopped
            if (acceleration.x >= 0.1){
                movingStarted = true
                counter = 0
            }
            else if (movingStarted){
                if (counter > 15){
                    OperationQueue.main.addOperation {
                        
                        print("inside outputAccelerationData method x:: \(acceleration.x), y :: \(acceleration.y), z :: \(acceleration.z)")
                        
                        self.counter=0
                        
                        // Cease movement and reset tracking variables
                        self.movingStarted = false
                        self.motionManager.stopAccelerometerUpdates()
                        
                        //stop the click event of button
                        self.startButton.isUserInteractionEnabled = false;
                        
                        //get data from pandorabot to speak
                        print("send to pb :: \(self.sendToPandorabot)")
                        
                        getTextFromPandorabot(self.sendToPandorabot, completion: {result in
                            
                            print("returned from pb :: \(result)")
                            self.textOfSpeech = result
                            print("*****This is the data from pandorabots (when motion stop is detected): \(self.textOfSpeech)")
                            
                            
                            //source: https://stackoverflow.com/questions/33138331/terminating-app-due-to-an-uncaught-exception-nsinternalinconsistencyexception
                            DispatchQueue.main.async(){
                                
                                //play speech and enable talk
                                self.speaking.text = "Play Audio!"
                                self.myUtterance = AVSpeechUtterance(string: self.textOfSpeech)
                                
                                self.myUtterance.rate = 0.5
                                print("I am here to speak :: \(self.myUtterance.speechString)")
                                self.synth.speak(self.myUtterance)
                                self.TalkToRobinButton.isHidden = false
                            }
                            
                            
                            
                        })
                        
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
    
    
    @IBAction func TalkToRobinClick(_ sender: UIButton) {
        
        
        //Stops accelerometer updates
        motionManager.stopAccelerometerUpdates()
        
        if audioEngine.isRunning {
            
            audioEngine.stop()
            recognitionRequest?.endAudio()
            
            TalkToRobinButton.isEnabled = true
            TalkToRobinButton.setTitle("Start Talking", for: .normal)
            
            //
            getTextFromPandorabot(self.speaking.text!, completion: {result in
                print("returned from func speak:: \(result)")
                self.textOfSpeech = result
                print("*****This is the data from pandorabots (conversation): \(self.textOfSpeech)")
                
                // speech captured so play speech and enable talk
                DispatchQueue.main.async(){
                
                    self.speaking.text = "Play Audio!"
                    self.myUtterance = AVSpeechUtterance(string: self.textOfSpeech)
                    self.myUtterance.rate = 0.5
                    print("I am here to speak :: \(self.textOfSpeech)")
                    self.synth.speak(self.myUtterance)
                    
                }
                
                self.TalkToRobinButton.isHidden = false
                
            })
            
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
                print("isFinal :: \(isFinal)")
                print("captured speech :: \(self.speaking.text)")
                

            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                self.audioEngine.inputNode?.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.TalkToRobinButton.isEnabled = true
            }
        })
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, _) in
            self?.recognitionRequest?.append(buffer)
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

