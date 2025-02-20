package thinglib.storage;

import thinglib.Util.ThingID;
import thinglib.ThingScape;
import thinglib.property.Component;
import thinglib.property.PropertyDef;
import thinglib.component.Entity;
import uuid.Uuid;
using haxe.EnumTools;

@:structInit
class Reference implements IHasReference{
    public var reference:Reference;
    public var parent:Reference;
    public var type(default, null):ReferenceType;
    public var value(default, null):ReferenceValue;
    public var guid(get, null):ThingID;
    public static inline var EMPTY_ID = Uuid.NIL;    
    public static inline var SKIP_REGISTRATION = "do not register";
    public static inline var THIS = "this";

    public function new(type:ReferenceType, parent:IHasReference, guid:ThingID, ?value:ReferenceValue){
        this.type = type;
        this.value = value;
        this.parent = parent?.reference;
        this.guid = guid;
        this.reference = this;
    }
    public static function Create(type:ReferenceType, ?parent:IHasReference, ?value:ReferenceValue){
        return new Reference(type, parent.reference, Uuid.short());
    }

    public function toString(){
    
        return (parent.type==ROOT||this.type==ROOT?'[root]':parent.toString()+'→[${type}:${value}]');        
    }

    function recursionTest(){
        var parents:Array<ThingID> = [this.guid];
        var cparent = parent;
        while(cparent!=null){
            var thingid:ThingID = switch cparent.value {
                case ENTITY(v):v.guid;
                case PROPERTYDEF(v):v.guid;
                case COMPONENT(v):v.guid;
                case ROOT(v):v.guid;
            }
            if(parents.contains(thingid)){
                var chain = "";
                for (p in parents){
                    var val = getRoot()?.getValue(p);
                    var name = val==null?p:switch getRoot().getValue(p) {
                        case ENTITY(v):v.name;
                        case PROPERTYDEF(v):v.name;
                        case COMPONENT(v):v.name;
                        case ROOT(v):v.name;
                    }
                    chain+='$name->';
                }
                return 'Circular reference ($thingid (${parent.type}) is its own ancestor!)\nTrace: $chain';
            }
            else{
                parents.push(thingid);
                cparent = cparent.parent;
            }
        }
        return "";
    }

    public function resolve<T:Thing>():T{
        if(value==null){
            this.value = getRoot().getValue(guid);
        }
        switch value {
            case ENTITY(v): return cast v;
            case PROPERTYDEF(v): return cast v;
            case COMPONENT(v): return cast v;
            case ROOT(v): return cast v;
        }
    }

    public function getRoot():ThingScape{
        if(type==ROOT){
            return resolve();
        }
        var ref = parent;
        while(ref!=null&&ref.type!=ROOT){
            ref=ref.parent;
        }
        if(ref==null){
            Util.log.error('[${type}:${guid}]; no path to a root.');
        }
        return switch ref.value {
            case ROOT(v): v;
            default: null;
        };
    }

    public function adopt(newParent:IHasReference){
        this.parent = newParent.reference;
    }
    
    function get_guid():String{
        if(value==null){
            return guid;
        }
        return switch value {
            case ENTITY(v):v.guid;
            case PROPERTYDEF(v): v.guid;
            case COMPONENT(v): v.guid;
            case ROOT(v):"root";
        };
    }
}

interface IHasReference{
    public var reference:Reference;
}

enum abstract ReferenceType(String) from String to String{
    var ENTITY;
    var PROPERTYDEF;
    var COMPONENT;
    var ROOT;
    var UNKNOWN;

    @:from
    static public function fromString(s:String) {
        if(createAll().contains(s)){
            return cast(s, ReferenceType);
        }
        else{
            return UNKNOWN;
        }
    }

    @:from
    static public function fromReferenceValue(r:ReferenceValue){
        return fromString(r.getName());
    }

    public static function createAll():Array<ReferenceType>{
        return [ENTITY, PROPERTYDEF, COMPONENT, ROOT];
    }
}
enum ReferenceValue{
    ENTITY(v:Entity);
    PROPERTYDEF(v:PropertyDef);
    COMPONENT(v:Component);
    ROOT(v:ThingScape);
}