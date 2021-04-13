
import Foundation
import MIOCore
import MIOCoreData

extension NSManagedObjectModel
{
	func registerDataModelRuntimeObjects(){

		_MIOCoreRegisterClass(type: SimpleEntity.self, forKey: "SimpleEntity")
	}
}

