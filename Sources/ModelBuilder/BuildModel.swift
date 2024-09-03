//
//  main.swift
//  MIOCoreData
//
//  Created by Javier Segura Perez on 31/8/24.
//

import Foundation
import ArgumentParser

@main
struct BuildModel: ParsableCommand
{
    @Flag(name: .long, help: "Obj-C support")
    var objc: Bool = false

    @Option( name: [.short, .long], help: "the config file" )
    var configPath: String?
    
    @Option(name: [.short, .customLong("output")], help: "the output folder")
    var outputFolder: String?
    
    @Argument(help: "the model file path")
    var modelFile: String
    
    mutating func run() throws
    {
        var enable = true
        
        let folder = outputFolder ?? FileManager.default.currentDirectoryPath
        if let cfg_path = configPath {
            if let cfg_data = FileManager.default.contents( atPath: cfg_path ) {
                if let json = try JSONSerialization.jsonObject(with: cfg_data ) as? [String:Any] {
                    enable = json[ "Enable" ] as? Bool ?? true
                }
            }
        }
        
        print("Option Enable: \(enable)")
        if enable == false { return }

        let parser = try ModelParser( withFilename: modelFile, outputPath: folder, type: objc == false ? .swift : .objc )
        parser.execute()
    }
}
