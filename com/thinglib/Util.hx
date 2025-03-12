package thinglib;

import debug.Logger;
import thinglib.storage.Reference;
import uuid.Uuid;
import thinglib.property.PropertyDef.PropertyType;
import thinglib.storage.Storage;
import thinglib.property.Override;
import thinglib.component.Entity;
import thinglib.property.core.CoreComponents;
import pasta.Vect;
using thinglib.component.util.EntityTools;
using Lambda;
using StringTools;
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

    public static function convertEntityToPrefabAndReplaceWithInstance(entity:Entity, root:ThingScape, storage:Storage, entityRemovedCallback:Entity->Void):PrefabConversionResult{
        //1. Save the entity as a file
        var overrides:Array<Override> = [];
        if(entity.hasPosition()){
            var e = entity.asPosition();
            overrides.push(new Override(Reference.THIS, CoreComponentPosition.X, FLOAT(e.local_position.x)));
            overrides.push(new Override(Reference.THIS, CoreComponentPosition.Y, FLOAT(e.local_position.y)));
            entity.asPosition().local_position=new Vect(0,0);
        }
        if(entity.isEdge()){
            var e = entity.asEdge();
            overrides.push(new Override(Reference.THIS, CoreComponentEdge.A, REF(e.a.guid)));
            overrides.push(new Override(Reference.THIS, CoreComponentEdge.B, REF(e.b.guid)));
        }
        var entity_children = entity.getChildrenRecursive();
        for(e in entity.getChildrenRecursive(true)){
            for(c in e.components){
                for(d in c.definitions){
                    var val = e.getValue(d);
                    var is_relevant:Bool = switch(val){
                        default: false;
                        case REF(v):
                            v!=entity.guid&&!entity_children.exists(c->c.guid==v);
                        case REFS(v):
                            var res = false;
                            for(ov in v){
                                if(ov!=entity.guid&&!entity_children.exists(c->c.guid==ov)){
                                    res = true;
                                    break;
                                }
                            }
                            res;
                    };
                    if(is_relevant){
                        var new_override = new Override(e.guid, d.guid, val);
                        overrides.push(new_override);
                        switch val {
                            default:
                            case REF(v):
                                e.setValue(d, REF(Reference.EMPTY_ID));
                            case REFS(v):
                                e.setValue(d, REFS(v.map(ov->(ov==entity.guid||entity_children.exists(c->c.guid==ov))?ov:Reference.EMPTY_ID)));
                        }
                    }
                }
            }
        }
        var res = storage.save(entity.filename, entity);
        if(!res){
            return {success:false};
        }
        //2. Re-parent it to the root node
        if(entityRemovedCallback!=null){
            entityRemovedCallback(entity);
        }
        var parent = entity.parent;
        //3. Create an instance of the entity at the old entity's location (need 'addAt' type option)
        var instance = Entity.CreateInstance(root, entity, overrides);
        var instance_children = instance.getChildrenRecursive();
        parent.replaceChild(entity, instance);
        entity.reference.adopt(root);
        //4. Recurse through all Components in the scene parented to the current construct
        for(e in instance_children){
            for(c in e.components){
                for(d in c.definitions){
                    var val = e.getValue(d);
                    switch(val){
                        default:
                        case REF(v):
                            if(entity_children.exists(c->c.guid==v)){
                                var new_ref = instance_children.find(c->c.guid.unInstancedID==v);
                                e.setValue(d, REF(new_ref.guid));
                            }
                            else if(v==entity.guid){
                                e.setValue(d, REF(instance.guid));
                            }
                        case REFS(v):
                            var new_refs=[];
                            var changed=false;
                            for(ov in v){
                                if(entity_children.exists(c->c.guid==ov)){
                                    var new_ref = instance_children.find(c->c.guid.unInstancedID==ov);
                                    new_refs.push(new_ref.guid);
                                    changed=true;
                                }
                                else if(ov==entity.guid){
                                    new_refs.push(instance.guid);
                                    changed=true;
                                }
                                else{
                                    new_refs.push(ov);
                                }
                            }
                            if(changed){
                                e.setValue(d, REFS(new_refs));
                            }
                    }
                }
            }
        }

        return {success:true, instance: instance};
    }
}

typedef PrefabConversionResult={
    success:Bool,
    ?instance:Entity
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

    public function resolveThis(to:ThingID){
        return this.replace(Reference.THIS, to);
    }

    public function toRelative(relative_root:ThingID){
        return this.replace(relative_root, Reference.THIS);
    }

    @:from
    static function fromThing(thing:Thing):ThingID{
        return thing.guid;
    }

    @:from
    static function fromThingArray(things:Array<HasGUID>):ThingID{
        return new ThingID(things.map(t->t.guid).join(DIV));
    }
}

typedef HasGUID = {guid:ThingID};