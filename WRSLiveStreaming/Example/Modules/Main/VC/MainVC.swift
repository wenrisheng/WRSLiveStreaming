//
//  MainVC.swift
//  WRSLiveStreaming
//
//  Created by jack on 2021/3/10.
//

import UIKit

class MainVC: UIViewController {

    @IBOutlet weak var preView: UIView!
    var session: WRSAVSession?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.session = WRSAVSession(sessionPreset: .vga640x480, position: .front, videoSize: CGSize(width: 640, height: 360))
        self.session?.preView = self.preView
        self.session?.startCapture()
    }


    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
