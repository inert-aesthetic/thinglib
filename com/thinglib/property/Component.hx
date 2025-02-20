package thinglib.property;

import thinglib.Util.ThingID;
import thinglib.storage.Dependency;
import thinglib.storage.Reference;
import uuid.Uuid;
import thinglib.storage.StorageTypes.SerializedComponent;
using Lambda;

class Component extends Thing{
    public var definitions:Array<PropertyDef> = [];
    public var base:Bool = false;
    public var requirements:Array<Component>;
    public var user_selectable:Bool = false;
    public function new(parent:IHasReference, name:String="", guid:String=null){
        this.name = name;
        this.extension = Consts.FILENAME_COMPONENT;
        this.guid=guid??Uuid.short();
        this.requirements=[];
        super(COMPONENT, parent);
    }

    override public function serialize(isRoot:Bool=true, ?ancestorDependencies:Array<Dependency>):SerializedComponent{
        var ret:SerializedComponent = {
            name: name,
            definitions: definitions.map(f->f.serialize()),
            guid: guid,
            user_selectable: user_selectable,
        }
        calculateDependencies();
        if(this.dependencies.length>0){
            ret.dependencies=this.dependencies.map(d->d.serialize());
        }
        return ret;
    }

    public function getDefByName(def:String):PropertyDef{
        for(d in definitions){
            if(d.name==def){
                return d;
            }
        }
        Util.log.warn('Def named "$def" not found on $dependencySignature.');
        return null;
    }

    public function hasDefByGUID(def:ThingID):Bool{
        for(d in definitions){
            if(d.guid==def){
                return true;
            }
        }
        return false;
    }

    public function getDefByGUID(def:ThingID):PropertyDef{
        for(d in definitions){
            if(d.guid==def){
                return d;
            }
        }
        Util.log.warn('Def with guid "$def" not found on $dependencySignature.');
        return null;
    }

    override public function calculateDependencies(){
        dependencies=[];
        requirements?.iter(r->r.assertDependency(dependencies));
    }

    override public function loadFromSerialized(parent:IHasReference, props:Dynamic, ?id_prefix:String):Void{
        var p:SerializedComponent = props;
        this.name = p.name;
        this.guid = p.guid;
        setReference(COMPONENT(this), parent);
        this.definitions = p.definitions.map(f->PropertyDef.fromSerialized(this, f));
        this.user_selectable = p.user_selectable??false;
        if(p.dependencies!=null){
            for(d in p.dependencies){
                var dep:Component = getRoot().getThing(COMPONENT, d.guid);
                if(dep!=null){
                    require(dep);
                }
            }
        }
        if(id_prefix!=null){
            Util.log.warn('Arg id_prefix given to ${this}, but such behavior is unspecified.');
        }
    }

    public function require(component:Component){
        if(component.base&&listRequirementsRecursive().exists(c->c.base)){
            Util.log.warn('Error: Tried to require base component $component on $this but it already has base requirement ${listRequirementsRecursive().find(c->c.base)}.');
            return;
        }
        if(this.requirements.length==0){
            requirements.push(component);
        }
        else if(!this.requires(component)&&!this.requiresUpstream(component)){
            requirements.push(component);
            calculateDependencies();
        }
    }

    public function removeRequirement(component:Component):Bool{
        if(this.requires(component)){
            requirements.remove(requirements.find(r->r.isEqualTo(component)));
            calculateDependencies();
            return true;
        }
        return false;
    }

    public function requires(component:Component):Bool{
        return requirements.exists(r->r.isEqualTo(component));
    }

    public function requiresUpstream(component:Component):Bool{
        for(r in requirements){
            if(r.requires(component)||r.requiresUpstream(component)){
                return true;
            }
        }
        return false;
    }

    public function listRequirementsRecursive():Array<Component>{
        var ret = [];
        for(r in requirements){
            ret.push(r);
            var upstream = r.listRequirementsRecursive();
            for(ur in upstream){
                if(!ret.exists(e->e.isEqualTo(ur))){
                    ret.push(r);
                }
            }
        }
        return ret;
    }

    public static function FromSerialized(parent:IHasReference, data:SerializedComponent){
        var ret = new Component(null, null, Reference.SKIP_REGISTRATION);
        ret.loadFromSerialized(parent, data);
        return ret;
    }
}