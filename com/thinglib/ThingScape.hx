package thinglib;

import uuid.Uuid;
import thinglib.Util.ThingID;
import thinglib.property.Component;
import thinglib.property.PropertyDef;
import thinglib.component.Entity;
import thinglib.storage.Storage;
import thinglib.storage.Dependency;
import thinglib.property.core.CoreComponents;
import thinglib.storage.Reference;
using Lambda;

class ThingScape extends Thing{
    var things:Map<ThingID, ReferenceValue> = new Map();
    public function new(){
        super(ROOT, null);
        reference.parent = reference;
        CoreComponents.initialize(this);
        guid=Uuid.short();
    }

    public function registerThing(thing:Thing){
        if(thing.guid==null){
            Util.log.error('Tried to register $thing with null guid.');
            return;
        }
        if(thing.guid==Reference.SKIP_REGISTRATION||guid==Reference.SKIP_REGISTRATION){
            return;
        }
        if(things.exists(thing.guid)){
            var existing:Thing = unsafeGet(thing.guid);
            if(existing==thing){
                Util.log.info('Skipping re-registering existing thing $thing.');
                return;
            }
            else{
                Util.log.error('Tried to register existing $thing.');
            }
        }
        things.set(thing.guid, switch thing.thingType {
            case ENTITY: ENTITY(cast thing);
            case PROPERTYDEF: PROPERTYDEF(cast thing);
            case COMPONENT: COMPONENT(cast thing);
            case ROOT: null;
            case UNKNOWN: null;
        });
    }

    public function resolveDependency<T:Thing>(parent:IHasReference, dependency:Dependency, storage:Storage):T{
        Util.log.info('Resolving dependency $dependency...');
        if(hasThing(dependency.guid)){
            Util.log.info("Resolved successfully.");
            return getThing(dependency.type, dependency.guid);
        }
        else{
            Util.log.info('Not loaded yet; loading from ${storage.working_directory}/${dependency.path}.');
            var target = switch dependency.type {
                case ENTITY: new Entity(this, null, null, Reference.SKIP_REGISTRATION);
                case COMPONENT: new Component(this, null, Reference.SKIP_REGISTRATION);
                default: null;
            }
            if(target==null){
                Util.log.error('Unresolvable dependency: ${dependency}');
                return null;
            }
            storage.loadFromFile(parent, cast(target), dependency.path);
            if(target.thingType!=dependency.type){
                Util.log.error('Dependency error: Dependency was of type ${dependency.type}, but resolved into ${target.thingType}.');
                return null;
            }
            Util.log.info("Resolved successfully.");
            return cast(target);
        }
    }

    //Only if you know what you are doing...
    public function unsafeGet<T:Thing>(guid:ThingID):T{
        return cast switch things.get(guid) {
            case ENTITY(v): v;
            case PROPERTYDEF(v): v;
            case COMPONENT(v): v;
            case ROOT(v): v;
        };
    }
    
    public function hasThing(guid:ThingID){
        return things.exists(guid);
    }

    public function getThing<T:Thing>(type:ReferenceType, guid:ThingID):T{
        var val = things.get(guid);
        if(val==null){
            Util.log.warn('Not found in root: [$type:$guid].');
            return null;
        }
        if(type==UNKNOWN||ReferenceType.fromReferenceValue(val)==type){
            return cast switch val {
                case ENTITY(v): v;
                case PROPERTYDEF(v): v;
                case COMPONENT(v): v;
                case ROOT(v): v;
            };
        }
        Util.log.error('Fatal: ${guid} (${val}) is not ${type}.');
        return null;
    }

    @:generic
    public function getAll<@:const T:Thing>(type:Class<T>):Array<T>{
        return cast things.filter(obj->
            {
                var dyn:Dynamic = switch obj {
                    case ENTITY(v):v;
                    case PROPERTYDEF(v):v;
                    case COMPONENT(v):v;
                    case ROOT(v):v;
                };
                var c = Type.getClass(dyn);
                if(c==type) return true;
                var s = Type.getSuperClass(c);
                if(s!=Thing&&s==type){
                    return true;
                }
                return false;
            }
        ).map(obj-> switch obj {
            case ENTITY(v): v;
            case PROPERTYDEF(v): v;
            case COMPONENT(v): v;
            case ROOT(v): v;
        });
    }

    public function getValue(guid:ThingID):ReferenceValue{
        var val = things.get(guid);
        if(val == null){
            Util.log.error('${guid} is not registered in root.');
        }
        return val;
    }

    public function removeThing(thing:Thing, ?guid:ThingID){
        things.remove(guid??thing.guid);
    }
}