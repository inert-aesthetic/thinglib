package thinglib.storage;
import haxe.crypto.Sha1;
import thinglib.Thing;
import thinglib.Util.ThingID;
import thinglib.storage.StorageTypes.SerializedDependency;
import thinglib.storage.Reference.IHasReference;
import thinglib.property.PropertyDef;
import thinglib.property.Property.PropertyValue;
import haxe.Json;
import haxe.io.Path;
using Lambda;
using StringTools;
import sys.FileSystem;
import sys.io.File;

class Storage{
    public var working_directory:Path = new Path("");
    public function new(directory){
        this.working_directory=new Path(directory);
        if(!FileSystem.exists(working_directory.toString())){
            FileSystem.createDirectory(working_directory.toString());
        }
    }
    public function save(filename:String, target:Thing):Bool{
        try{
            File.saveContent(working_directory.dir+"/"+filename, Json.stringify(target.serialize(), replacer, "\t"));
            return true;
        }
        catch(e){
            Util.log.error('Failed to save $target. Error: "$e"');
            return false;
        }
    };

    public function loadMeta(filename:String){
        var filen = working_directory.dir+"/"+filename;
        if(!FileSystem.exists(filen)){
            Util.log.error("File not found: "+filen);
            return null;
        }
        var raw = File.getContent(filen);
        return parseMeta(raw);
    }

    function parseMeta(blob:String){
        var content:StorageMeta = Json.parse(blob);
        content.hash = Sha1.encode(blob);
        return content;
    }

    @:generic
    public function createFromFile<@:const T:Thing>(type:Class<T>, parent:IHasReference, filename:String):T{
        var filen = working_directory.dir+"/"+filename;
        if(!FileSystem.exists(filen)){
            Util.log.error("File not found: "+filen);
            return null;
        }
        var root = parent.reference.getRoot();
        var existing:Thing=null;
        var raw = File.getContent(filen);
        var content:StorageMeta = parseMeta(raw);
        if(content.guid!=null&&root.hasThing(content.guid)){
            existing = root.getThing(UNKNOWN, content.guid);
        }
        if(existing!=null){
            if(!existing.isHashMatch(raw)){
                Util.log.warn('File on disk has changed but data not reloaded for $filename ($existing).');
            }
            // existing.loadFromSerialized(parent, content); TODO Create 'update from serialized'
            return cast(existing);
        }
        else{
            var ret = createFromSerialized(type, parent, content);
            ret.setHash(raw);
            return ret;
        }
    }

    public function createFromSerialized<@:const T:Thing>(type:Class<T>, parent:IHasReference, content:StorageMeta):T{
        var builder = Reflect.field(type, "FromSerialized");
        if(content.dependencies?.length>0){
            Util.log.verbose('Resolving dependencies for ${content.name}');
            resolveDependencies(parent, content.dependencies);
        }
        var root = parent.reference.getRoot();
        var existing:Thing=null;
        if(content.guid!=null&&root.hasThing(content.guid)){
            existing = root.getThing(UNKNOWN, content.guid);
        }
        if(existing!=null){
            // existing.loadFromSerialized(parent, content); TODO Create 'update from serialized'.
            return cast(existing);
        }
        else{
            return Reflect.callMethod(builder==null?Thing:type, builder??Reflect.field(type, "FromSerialized"), [parent, content]);
        }
    }

    public function resolveDependencies(parent:IHasReference, dependencies:Array<SerializedDependency>){
        if(dependencies?.length>0){
            var root=parent.reference.getRoot();
            if(root==null){
                Util.log.error('Unable to resolve dependencies as $parent has no path to root.');
            }
            else{
                for(dep in dependencies.map(d->Dependency.FromSerialized(d))){
                    var res = root.resolveDependency(parent, dep, this);
                    if(res==null){
                        Util.log.error('Failed to resolve depencency: $dep');
                    }
                }
            }
        }
    }

    public function loadFromFile(parent:IHasReference, target:Thing, filename:String):Void{
        var filen = working_directory.dir+"/"+filename;
        if(!FileSystem.exists(filen)){
            Util.log.error("File not found: "+filen);
            return;
        }
        var raw = File.getContent(filen);
        var content = parseMeta(raw);
        if(content.dependencies?.length>0){
            Util.log.verbose('Resolving dependencies for $filename');
            resolveDependencies(parent, content.dependencies);
        }
        target.loadFromSerialized(parent, content);
    }

    static function replacer(k:Dynamic, v:Dynamic):Dynamic{
        switch(Type.typeof(v)){
            case TEnum(e):
                return switch(e.getName()){
                    case "thinglib.property.PropertyValue":
                        var pv:PropertyValue = v;
                        return PropertyDef.SerializeValue(pv);
                    default: v;
                }
            default: return v;
        }
    }
}

typedef StorageMeta = {
    guid:ThingID,
    name:String,
    hash:String,
    ?dependencies:Array<SerializedDependency>
}