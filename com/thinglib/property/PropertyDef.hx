package thinglib.property;

import thinglib.Util.ThingID;
import thinglib.storage.Dependency;
import thinglib.storage.Reference;
import thinglib.storage.StorageTypes.SerializedPropertyValue;
import thinglib.property.Property.PropertyValue;
import thinglib.storage.StorageTypes.SerializedPropertyDef;
import uuid.Uuid;

class PropertyDef extends Thing{
    public static inline var BASE_NODE:String = "node";
    public static inline var BASE_EDGE:String = "edge";
    public static inline var BASE_GROUP:String = "group";
    public static inline var BASE_REGION:String = "region";
    public static inline var BASE_PATH:String = "path";
    public static inline var CORE_DEFS:String = "core";
    public var type:PropertyType;
    var _default_value:PropertyValue;
    public var default_value(get, set):PropertyValue; 
    public var maximum_value:PropertyValue;
    public var minimum_value:PropertyValue;
    public var options:Array<String>;
    public var step_size:PropertyValue;
    public var ref_base_type_guid:ThingID;
    public var extra_data:String;
    public var documentation:String;
    public var full_name(get, never):String;
    public var timeline_controllable:Bool=true;

    public var component:Component;

    public function new(component:Component, ?name:String, ?type:PropertyType, ?guid:String){
        this.name=name;
        this.type=type;
        this.guid=guid??Uuid.short();
        this.component = component;
        super(PROPERTYDEF, component.reference);
    }

    override public function serialize(isRoot:Bool=true, ?ancestorDependencies:Array<Dependency>):SerializedPropertyDef{
        var ret:SerializedPropertyDef = {
            name: name,
            guid: guid,
            default_value:SerializeValue(default_value),
            min: SerializeValue(minimum_value),
            max: SerializeValue(maximum_value),
            step: SerializeValue(step_size),
            type: type,
            extra: extra_data,
            documentation: documentation,
            options: options,
            timeline_controllable: timeline_controllable
        };
        if(ref_base_type_guid != Reference.EMPTY_ID){
            ret.ref_base_type = ref_base_type_guid;
        }
        return ret;
    }

    inline function get_full_name():String{
        return '${component.name}::${name}';
    }

    public function defaultValInt():Int{
        switch(default_value){
            case INT(v): return v;
            case COLOR(v): return v;
            case SELECT(v): return v;
            default: return 0;
        }
    }
    public function defaultValBool():Bool{
        switch(default_value){
            case BOOL(v): return v;
            default: return false;
        }
    }
    public function minValInt():Int{
        if(minimum_value==null) return 0x80000000;
        switch(minimum_value){
            case INT(v): return v;
            default: return 0;
        }
    }
    public function maxValInt():Int{
        if(maximum_value==null) return 0x7fffffff;
        switch(maximum_value){
            case INT(v): return v;
            default: return 0;
        }
    }
    public function stepValInt():Int{
        if(step_size==null) return 1;
        switch(step_size){
            case INT(v): return v;
            default: return 0;
        }
    }

    public function defaultValFloat():Float{
        switch(default_value){
            case FLOAT(v): return v;
            default: return 0;
        }
    }
    public function minValFloat():Float{
        if(minimum_value==null) return Math.NEGATIVE_INFINITY;
        switch(minimum_value){
            case FLOAT(v): return v;
            default: return 0;
        }
    }
    public function maxValFloat():Float{
        if(maximum_value==null) return Math.POSITIVE_INFINITY;
        switch(maximum_value){
            case FLOAT(v): return v;
            default: return 0;
        }
    }
    public function stepValFloat():Float{
        if(step_size==null) return 0.1;
        switch(step_size){
            case FLOAT(v): return v;
            default: return 0;
        }
    }    
    public function defaultValString():String{
        switch(default_value){
            case STRING(v): return v;
            default: return "";
        }
    }

    public function defaultValIntArray():Array<Int>{
        switch(default_value){
            case MULTI(v):
                return v;
            default: return [];
        }
    }

    public static function fromSerialized(parent_component:Component, p:SerializedPropertyDef):PropertyDef{
        var ret = new PropertyDef(parent_component, null, null, Reference.SKIP_REGISTRATION);
        ret.loadFromSerialized(parent_component.reference, p);
        return ret;
    }

    function get_default_value():PropertyValue{
        if(this._default_value!=null&&this._default_value!=NONE){
            return this._default_value;
        }
        return switch this.type {
            case INT: INT(0);
            case FLOAT: FLOAT(0);
            case STRING: STRING("");
            case BOOL: BOOL(false);
            case COLOR: COLOR(0x000);
            case SELECT: SELECT(0);
            case MULTI: MULTI([]);
            case REF: REF(Reference.EMPTY_ID);
            case REFS: REFS([]);
            case BLANK: BLANK;
            default: BLANK;
        }
    }

    function set_default_value(to:PropertyValue){
        this._default_value = to;
        return to;
    }

    public static function SerializeValue(pv:PropertyValue):SerializedPropertyValue{
        if(pv==null){
            return null;
        }
        return switch pv{
            case INT(v): {type:PropertyType.INT, value:v};
            case FLOAT(v): {type:PropertyType.FLOAT, value:v};
            case STRING(v): {type:PropertyType.STRING, value:v};
            case BOOL(v): {type:PropertyType.BOOL, value:v};
            case COLOR(v): {type:PropertyType.COLOR, value:v};
            case SELECT(v): {type:PropertyType.SELECT, value:v};
            case MULTI(v): {type:PropertyType.MULTI, value:v};
            case REF(v): {type:PropertyType.REF, value:v};
            case REFS(v): {type:PropertyType.REFS, value:v};
            case URI(v): {type:PropertyType.URI, value:v};
            default: {type:PropertyType.UNKNOWN, value:""};
        }
    }

    public static function DeserializeValue(d:SerializedPropertyValue):PropertyValue{
        if(d==null){
            return NONE;
        }
        var v:Dynamic = d.value;
        return switch d.type {
            case INT: INT(cast v);
            case FLOAT: FLOAT(cast v);
            case STRING: STRING(cast v);
            case BOOL: BOOL(cast v);
            case COLOR: COLOR(cast v);
            case SELECT: SELECT(cast v);
            case MULTI: MULTI(cast v);
            case REF: REF(v);
            case REFS: REFS(v);
            case URI: URI(v);
            case BLANK: BLANK;
            case UNKNOWN: NONE;
        };
    }

    override public function loadFromSerialized(parent:IHasReference, data:Dynamic, ?id_prefix:String) {
        var p:SerializedPropertyDef = data;
        this.name = p.name;
        this.type = p.type;
        this.guid = p.guid;
        if(p.default_value!=null){
            this._default_value = DeserializeValue(p.default_value);
        }
        this.minimum_value = DeserializeValue(p.min);
        this.maximum_value = DeserializeValue(p.max);
        this.step_size = DeserializeValue(p.step);
        this.extra_data = p.extra;
        this.documentation = p.documentation;
        this.options = p.options;
        this.ref_base_type_guid = p.ref_base_type??Reference.EMPTY_ID;
        this.timeline_controllable = p.timeline_controllable??true;
        setReference(PROPERTYDEF(this), parent);
        if(id_prefix!=null){
            Util.log.warn('Arg id_prefix given to ${this}, but such behavior is unspecified.');
        }
    }

    //PropertyDefs can't be loaded, so load prop def list?
    override function get_dependencySignature():Dependency {
        return component.dependencySignature; 
    }
}

enum abstract PropertyType(String) to String{
    var INT;
    var FLOAT;
    var STRING;
    var BOOL;
    var COLOR;
    var SELECT;
    var MULTI;
    var REF;
    var REFS;
    var URI;
    var BLANK; 
    var UNKNOWN;

    @:from
    static public function fromString(s:String) {
        return switch s {
            case INT:INT;
            case FLOAT:FLOAT;
            case STRING:STRING;
            case BOOL:BOOL;
            case COLOR:COLOR;
            case SELECT:SELECT;
            case MULTI:MULTI;
            case REF:REF;
            case REFS:REFS;
            case URI:URI;
            case BLANK:BLANK;
            default: UNKNOWN;
        }
    }
    @:from
    static public function fromPropertyValue(value:PropertyValue){
        if(value==null) return null;
        return switch value {
            case PropertyValue.INT(v): INT;
            case PropertyValue.FLOAT(v): FLOAT;
            case PropertyValue.STRING(v): STRING;
            case PropertyValue.BOOL(v): BOOL;
            case PropertyValue.COLOR(v): COLOR;
            case PropertyValue.SELECT(v): SELECT;
            case PropertyValue.MULTI(v): MULTI;
            case PropertyValue.REF(v): REF;
            case PropertyValue.REFS(v): REFS;
            case PropertyValue.URI(v): URI;
            case PropertyValue.BLANK: BLANK;
            case PropertyValue.NONE: UNKNOWN;
        }
    }
    public static function createAll():Array<PropertyType>{
        return [INT, FLOAT, STRING, BOOL, COLOR, SELECT, MULTI, REF, REFS, URI];
    }
}