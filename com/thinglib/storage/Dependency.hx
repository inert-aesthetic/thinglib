package thinglib.storage;

import thinglib.storage.StorageTypes.SerializedDependency;
import thinglib.storage.Reference.ReferenceType;

class Dependency{
    public var type:ReferenceType;
    public var guid:String;
    public var path:String;
    public function new(type, guid, path){
        this.type=type;
        this.guid=guid;
        this.path=path;
    }
    public function serialize(isRoot:Bool=true):SerializedDependency{
        return {type:type, guid:guid, path:path};
    }
    public static function FromSerialized(data:SerializedDependency){
        return new Dependency(data.type, data.guid, data.path);
    }
    public function toString():String {
        return '[$type:$guid->$path]';
    }
    public function isEqualTo(other:Dependency):Bool{
        return type==other.type&&guid==other.guid&&path==other.path;
    }
    public function isOfThing(thing:Thing):Bool{
        return this.isEqualTo(thing.dependencySignature);
    }
}