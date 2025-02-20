package thinglib;

import debug.Logger;
import thinglib.storage.Reference;
import uuid.Uuid;
import thinglib.property.PropertyDef.PropertyType;
#if !js
import sys.FileSystem;
#end

class Util{

    public static var log = new Logger("Thinglib", WARN, NONE);

    public static function fileName(name:String, extension:String, dir:String=""):Dynamic{
        return dir+(dir==""?"":"\\")+name+"."+extension;
    }

    public static function getAllOfTypeInDirectory(typename:String, directory:String):Array<String>{
        var ret = [];
        #if !js
        typename = short(typename);
        var allfiles = FileSystem.readDirectory(directory);
        for(f in allfiles){
            var exp = f.split(".");
            if(exp.length>=3&&exp[exp.length-2]==typename){
                ret.push(f);
            }
        }
        #end
        return ret;
    }

    public static function short(filename:String):String{
        return filename.substr(0, filename.lastIndexOf("."));
    }

    //TODO Make this better
    //It is not to be used for anything that will fail if not unique.
    private static var used_name_tails:Array<String> = [];
    public static function name_tail():String{
        var ret:String;
        while(used_name_tails.contains(ret = Uuid.short().substr(0, 4))){}
        used_name_tails.push(ret);
        return ret;
    }
}

abstract ThingID(String) from String to String{
    static inline var DIV = ":";
    /**
        If this is from an instance, it will be the top level parent's ID.
        Otherwise, it'll be its own.
    **/
    public var topLevelID(get, never):ThingID;
    /**
        Gets the underlying ID of this item, which will be in its prefab if it's an instance.
    **/
    public var ownID(get, never):ThingID;
    /**
        If this is a nested prefab, this gets the ID of the prefab it's directly from.
        Otherwise, it gets an empty ID.
    **/
    public var oneAboveID(get, never):ThingID;
    /**
        Gets everything below the top level instance ID for this thing.
    **/
    public var unInstancedID(get, never):ThingID;
    public function new(id:String){
        this=id;
    }

    function get_topLevelID(){
        return this.split(DIV)[0];
    }
    
    function get_ownID(){
        return this.split(DIV).pop();
    }

    function get_unInstancedID(){
        var exploded = this.split(DIV);
        if(exploded.length==1){
            return this;
        }
        return exploded.slice(1).join(DIV);
    }

    function get_oneAboveID(){
        var res = this.split(DIV);
        if(res.length>=2){
            return res[res.length-2];
        }
        return Reference.EMPTY_ID;
    }

    @:from
    static function fromThingArray(things:Array<HasGUID>):ThingID{
        return new ThingID(things.map(t->t.guid).join(DIV));
    }
}

typedef HasGUID = {guid:ThingID};