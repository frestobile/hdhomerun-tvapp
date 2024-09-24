//
//  CloudKitManager.swift
//  LiveTV
//
//  Created by CodingGuru on 9/12/24.
//

import Foundation
import CloudKit

class CloudKitManager {
    let container = CKContainer.default()
    
    func saveTuner(tuner: String) {
        let record = CKRecord(recordType: "Tuner")
        record["tunerName"] = tuner as CKRecordValue
        container.privateCloudDatabase.save(record) { record, error in
            if let error = error {
                print("Error saving to CloudKit: \(error)")
            }
        }
    }
}
