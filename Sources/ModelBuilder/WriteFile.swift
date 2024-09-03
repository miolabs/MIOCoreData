//
//  WriteFile.swift
//  MIOCoreData
//
//  Created by Javier Segura Perez on 31/8/24.
//

import Foundation

func WriteDataFile(data:Data?, path:String?) {
    
    if (path == nil) {
        print("Error writing file: Path is nil")
        return;
    }
    
    if (data == nil) {
        print("Error writing file: Data is nil.")
        return;
    }
    
    do {
        try data!.write(to: URL.init(fileURLWithPath: path!))
        print("File save: \(path!)")
    }
    catch {
        print("ERROR: It was not possible to write on the file")
    }
}


func WriteTextFile(content:String, path:String?) {
    
    let data : Data? = content.data(using: .utf8)
    WriteDataFile(data:data, path:path);
}
