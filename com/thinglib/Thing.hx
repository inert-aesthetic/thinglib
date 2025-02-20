package thinglib;

import haxe.crypto.Sha1;
import thinglib.Util.ThingID;
import haxe.Json;
import thinglib.storage.Dependency;
import thinglib.storage.Reference;
import thinglib.storage.Reference.ReferenceType;
using Lambda;

class Thing implements IHasReference{
    public var guid:ThingID;
    public var name:String;
    public var extension(default, null):String;
    public var dependencies:Array<Dependency>;
    public var dependencySignature(get, null):Dependency;
    public var filename(get, null):String;
    public var reference:Reference;
    public var thingType(default, null):ReferenceType;
    public var skipSerialization:Bool = false;
    public var isFromInstance:Bool = false; //TODO calculate this and make it more robust
    public var hash:String = null;
    
    function new(thingType:ReferenceType, parent:IHasReference){
        this.thingType=thingType;
        setReference(switch thingType {
            case ENTITY:ENTITY(cast this);
            case PROPERTYDEF:PROPERTYDEF(cast this);
            case COMPONENT:COMPONENT(cast this);
            case ROOT:ROOT(cast this);
            default:null;
        }, parent);
    }
    function setReference(value:ReferenceValue, parent:IHasReference){
        this.reference = new Reference(ReferenceType.fromReferenceValue(value), parent, guid, value);
        parent?.reference.getRoot()?.registerThing(this);
    }
    function get_filename():String{
        return '${name}.${extension}';
    }
    function calculateDependencies(){

    }
    function getRoot():ThingScape{
        return reference.getRoot();
    }
    function get_dependencySignature():Dependency{
        return new Dependency(this.thingType, this.guid, this.filename);
    }
    public function assertDependency(list:Array<Dependency>){
        var myDep = get_dependencySignature();
        if(myDep==null){
            return;
        }
        if(list.exists(dep->dep.guid==myDep.guid&&dep.path==myDep.path&&dep.type==myDep.type)){
            return;
        }
        list.push(myDep);
    }

    @:allow(thinglib.Storage)
    private static inline var FromSerializedMethodName = "FromSerialized";

    @:keep
    public static function FromSerialized(parent:IHasReference, data:Dynamic):Thing{
        Util.log.error('FromSerialized not implemented on call for ${Json.stringify(data)} on $parent.');
        return new Thing(UNKNOWN, parent);
    }
    public function serialize(isRoot:Bool=true, ?ancestorDependencies:Array<Dependency>):Dynamic{
        Util.log.error('Serialize not implemented on $name ($thingType:$guid).');
        return {};
    };
    public function loadFromSerialized(parent:IHasReference, data:Dynamic, ?id_prefix:String):Void{
        Util.log.error('loadFromSerialized not implemented on $name ($thingType:$guid) for parent $parent.');
    };
    public function setHash(data:String){
        hash = Sha1.encode(data);
    }
    public function isHashMatch(data:String){
        return hash!=null&&hash==Sha1.encode(data);
    }
    public function toString():String{
        return '$name($thingType):$guid';
    }
    public function isEqualTo(thing:Thing):Bool{
        return this.guid==thing.guid;
    }
}