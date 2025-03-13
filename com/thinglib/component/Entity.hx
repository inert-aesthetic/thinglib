package thinglib.component;
import thinglib.property.Property.PropertyValue;
import haxe.ds.ArraySort;
import thinglib.storage.StorageTypes.SerializedProperty;
import thinglib.timeline.Timeline;
import thinglib.property.core.CoreComponents.CoreComponent;
import thinglib.property.Component;
import thinglib.storage.StorageTypes.ChildRegistryEntry;
import thinglib.Util.ThingID;
import thinglib.property.Override;
import thinglib.storage.Dependency;
import thinglib.storage.Reference;
import thinglib.property.PropertyDef;
import thinglib.storage.StorageTypes.SerializedEntity;
import uuid.Uuid;
using Lambda;
using thinglib.component.util.EntityTools;
using thinglib.component.util.PropertyValueTools;

class Entity extends Thing{
    public var timeline(get, default):Timeline;
    var property_values:Map<ThingID, PropertyValue>;
    public var components:Array<Component>;
    public var children:Array<Entity>;
    public var parent(get, never):Entity;
    public var instanceOf:Entity;
    public var overrides:Array<Override>;
    public var children_base_entity:Entity;
    public var children_base_component:Component;


    public function new(?parent:IHasReference, ?name:String, ?children:Array<Entity>, ?guid:ThingID) {
        this.extension = Consts.FILENAME_CONSTRUCT;
        this.guid = guid??Uuid.short();
        this.name = name??"Entity_"+Util.name_tail();
        this.components = [];
        this.dependencies=[];
        this.overrides=[];
        this.children = children??[];
        this.property_values=[];
        super(ENTITY, parent);
    }

    public function setOverrideValue(definition:PropertyDef, target:Entity, value:PropertyValue){
        var existing_override = overrides.find(o->o.def_guid==definition.guid&&o.parent_guid==target.guid.unInstancedID);
        if(existing_override==null){
            existing_override = new Override(target.guid.unInstancedID, definition.guid, value);
            overrides.push(existing_override);
        }
        else{
            existing_override.value = value;
        }
    }

    public function getOverrideValue(definition:PropertyDef, target:Entity){
        var existing_override = overrides.find((o->o.def_guid==definition.guid&&o.parent_guid==target.guid.unInstancedID));
        if(existing_override!=null){
            return existing_override.value;
        }
        else return null;
    }

    public function hasOverrideValue(definition:PropertyDef, target:Entity):Bool{
        return overrides.exists(o->o.def_guid==definition.guid&&o.parent_guid==target.guid.unInstancedID);
    }

    public function isOverridden(definition:PropertyDef){
        if(isFromInstance){
            return getTopLevelInstance().hasOverrideValue(definition, this);
        }
        else if(instanceOf!=null){
            return instanceOf.hasPropByDef(definition)&&property_values.exists(definition.guid);
        }
        return false;
    }

    public function clearOverride(definition:PropertyDef){
        if(isFromInstance){
            var tli = getTopLevelInstance();
            var o = tli.overrides.find(o->o.def_guid==definition.guid&&o.parent_guid==this.guid.unInstancedID);
            if(o!=null){
                tli.overrides.remove(o);
            }
        }
        else if(instanceOf!=null){
            removeProperty(definition);
        }
    }

    public function getTopLevelInstance():Entity{
        if(!this.isFromInstance){
            Util.log.warn('Tried to get top level instance of $this, but it is not from an instance.');
            return null;
        }
        var ret = this.parent;
        while(ret.isFromInstance){
            ret = ret.parent;
            if(ret==null){
                Util.log.warn('Ran out of parents looking for top level instance of $this.');
                return null;
            }
        }
        return ret;
    }

    public function setValue(definition:PropertyDef, value:PropertyValue){
        // if timeline controlled we will edit the frame, not the property value
        if(components.exists(c->c.isEqualTo(definition.component))){
            if(timeline!=null&&this.hasTimelineController()){
                var tc = this.asTimelineControlled();
                var frame=tc.frame;
                var state=tc.current_state;
                if(state != null){
                    var track = state.getTrackFor(definition);
                    if(track != null) {
                        var exact = track.getKeyframe(frame);
                        if(exact!=null){
                            exact.value = track.offset==ABSOLUTE?value:value=value.subtract(getValueIgnoreTimeline(definition));
                            return;
                        }
                        var prev = track.getPreviousKeyframe(frame);
                        var next = track.getNextKeyframe(frame);
                        if(prev!=null){
                            if(next==null||next.keyframe.interpolation==NONE){
                                prev.keyframe.value=track.offset==ABSOLUTE?value:value=value.subtract(getValueIgnoreTimeline(definition));
                            }
                            return;
                        }
                        if(frame>0&&next!=null&&next.keyframe.interpolation!=NONE){
                            return;
                        }
                    }
                }
            }
            if(this.isFromInstance){
                var top_level_instance:Entity = getTopLevelInstance();
                top_level_instance.setOverrideValue(definition, this, value);
            }
            else{
                property_values.set(definition.guid, value);
            }
        }
        else{
            trace('Tried to set $definition to $value on $this but component ${definition.component} not there.');
        }
    }

    public function setValueFromDynamic(definition:PropertyDef, value:Dynamic){
        var new_value:PropertyValue = switch definition.type {
            case INT: INT(Std.parseInt(Std.string(value)));
            case FLOAT: FLOAT(Std.parseFloat(Std.string(value)));
            case STRING: STRING(Std.string(value));
            case BOOL: BOOL(Std.string(value)=="true");
            case COLOR: COLOR(value);
            case SELECT: SELECT(Std.parseInt(Std.string(value)));
            case MULTI: null;
            default: NONE;
        }
        var old_value = this.getValue(definition);
        if(new_value.equals(old_value)){
            return false;
        }
        setValue(definition, new_value);
        return true;
    }


    public function changeWillAffectValue(definition:PropertyDef){
        if(components.exists(c->c.isEqualTo(definition.component))){
            if(timeline!=null&&this.hasTimelineController()){
                var tc = this.asTimelineControlled();
                var frame=tc.frame;
                var state=tc.current_state;
                if(state != null){
                    var track = state.getTrackFor(definition);
                    if(track != null) {
                        var exact = track.getKeyframe(frame);
                        if(exact!=null){
                            return false;
                        }
                        var prev = track.getPreviousKeyframe(frame);
                        var next = track.getNextKeyframe(frame);
                        if(prev!=null){
                            return false;
                        }
                        if(frame>0&&next!=null&&next.keyframe.interpolation!=NONE){
                            return false;
                        }
                    }
                }
            }
        }
        return true;
    }

    public function getValueForFrame(definition:PropertyDef, state:TimelineState, frame:Int):PropertyValue{
        if(!definition.timeline_controllable||state==null||timeline==null){
            return getValueIgnoreTimeline(definition);
        }
        else{
            var track = state.getTrackFor(definition);
            if(track == null) return getValueIgnoreTimeline(definition);
            var origin:PropertyValue = getValueIgnoreTimeline(definition);
            var exact = track.getKeyframe(frame);
            if(exact!=null){
                return track.offset==ABSOLUTE?exact.value:exact.value.add(origin);
            }
            var prev = track.getPreviousKeyframe(frame);
            var next = track.getNextKeyframe(frame);
            var start_v:PropertyValue;
            if(prev==null){
                start_v = origin;
            }
            else{
                start_v = track.offset==ABSOLUTE?prev.keyframe.value:prev.keyframe.value.add(origin);
            }
            if(next==null||next.keyframe.interpolation==NONE){
                return start_v;
            }
            var end_v:PropertyValue = track.offset==ABSOLUTE?next.keyframe.value:next.keyframe.value.add(origin);
            var ratio = (frame-(prev?.frame??0))/(next.frame-(prev?.frame??0));
            switch definition.type {
                case INT:
                    var start = switch start_v {
                        case INT(v):v;
                        default:null;
                    }
                    var end = switch end_v{
                        case INT(v):v;
                        default:null;
                    }
                    return INT(Math.round(start+(end-start)*ratio));
                case FLOAT:
                    var start = switch start_v {
                        case FLOAT(v):v;
                        default:null;
                    }
                    var end = switch end_v{
                        case FLOAT(v):v;
                        default:null;
                    }
                    return FLOAT(start+(end-start)*ratio);
                case COLOR:
                    var start = switch start_v{
                        case COLOR(v):v;
                        default:null;
                    }
                    var end = switch end_v{
                        case COLOR(v):v;
                        default:null;
                    }
                    var start_r = 0xff&(start>>16);
                    var start_g = 0xff&(start>>8);
                    var start_b = 0xff&(start);
                    var end_r = 0xff&(end>>16);
                    var end_g = 0xff&(end>>8);
                    var end_b = 0xff&(end);
                    var lerp_r = Math.round(start_r+(end_r-start_r)*ratio);
                    var lerp_g = Math.round(start_g+(end_g-start_g)*ratio);
                    var lerp_b = Math.round(start_b+(end_b-start_b)*ratio);
                    return INT((lerp_r<<16)|(lerp_g<<8)|lerp_b);
                default:
                    return start_v;
            }
        }
    }

    public function getValueIgnoreTimeline(definition:PropertyDef):PropertyValue{
        if(this.isFromInstance&&getTopLevelInstance()?.hasOverrideValue(definition, this)){
            return getTopLevelInstance().getOverrideValue(definition, this);
        }
        else if(property_values.exists(definition.guid)){
            return property_values.get(definition.guid);
        }
        if(instanceOf?.hasPropByDef(definition)){
            return instanceOf.getValue(definition);
        }
        return definition.default_value??NONE;
    }

    public function getValueByGUID(guid:ThingID){
        for(c in components){
            for(d in c.definitions){
                if(d.guid==guid){
                    return getValue(d);
                }
            }
        }
        Util.log.warn('No prop with def id $guid on $this.');
        return null;
    }
    public function setValueByGUID(guid:ThingID, value:PropertyValue):PropertyValue{
        for(c in components){
            for(d in c.definitions){
                if(d.guid==guid){
                    setValue(d, value);
                    return value;
                }
            }
        }
        Util.log.warn('No prop with def id $guid on $this.');
        return null;
    }

    public function getValue(definition:PropertyDef):PropertyValue{
        if(!components.exists(c->c.isEqualTo(definition.component))){
            trace('Tried to get $definition value from $this but component ${definition.component} not there.');
        }
        if(definition.timeline_controllable&&timeline!=null&&this.hasTimelineController()){
            var tc = this.asTimelineControlled();
            return getValueForFrame(definition, tc.current_state, tc.frame);
        }
        else{
            return getValueIgnoreTimeline(definition);
        }
    }
    public function getValueByName(name:String):PropertyValue{
        for(c in components){
            var d = c.getDefByName(name);
            if(d!=null){
                return getValue(d);
            }
        }
        Util.log.error('No prop named $name on $this.');
        return NONE;
    }

    public function clearValue(definition:PropertyDef){
        property_values.remove(definition.guid);
    }

    //TODO Add a 'ancestor dependencies' var to pass forward, so only the parent holds all unique dependencies.
    override public function serialize(isRoot:Bool=true, ?ancestorDependencies:Array<Dependency>):SerializedEntity{
        calculateDependencies();
        var initialDependencyHolder=ancestorDependencies==null;
        if(initialDependencyHolder){
            ancestorDependencies=this.dependencies;
        }
        else{
            for(d in this.dependencies){
                if(!ancestorDependencies.exists(ad->ad.guid==d.guid)){
                    ancestorDependencies.push(d);
                }
            }
        }
        var wasRoot=isRoot;
        var relevant_children:Array<Entity>;
        if(!isRoot||this.instanceOf==null){
            relevant_children=this.children;
        }
        else{
            relevant_children=this.getChildrenRecursive(false);
            isRoot=false;
        }
        relevant_children = wasRoot?relevant_children.filter(e->!e.isFromInstance&&!e.skipSerialization):[];
        var ret:SerializedEntity = {
            name:name,
            guid:guid,
        };
        if(relevant_children.length>0){
            ret.children=relevant_children.map(c->c.serialize(isRoot, ancestorDependencies));
        }
        if(initialDependencyHolder&&dependencies.length>0){
            ret.dependencies=dependencies.map(d->d.serialize(isRoot));
        }
        if(instanceOf!=null){
            ret.base_guid=instanceOf.guid;
        }
        var ret_properties:Array<SerializedProperty> = [];
        for(key=>val in property_values){
            ret_properties.push({definition:key, value:PropertyDef.SerializeValue(val)});
        }
        if(ret_properties.length>0){
            ArraySort.sort(ret_properties, (a, b)->Std.string(a.definition)<Std.string(b.definition)?-1:Std.string(a.definition)>Std.string(b.definition)?1:0);
            ret.properties = ret_properties;
        }
        if(overrides.length>0){
            ret.overrides=overrides.map(o->o.serialize(isRoot));
        }
        if(children_base_entity!=null){
            ret.children_base_entity = children_base_entity.guid;
        }
        else if(children_base_component!=null){
            ret.children_base_component = children_base_component.guid;
        }
        if(components.length>0){
            var comp = components.filter(c->instanceOf==null||!instanceOf.hasComponentByGUID(c.guid)).map(p->p.guid);
            if(comp.length>0){
                ret.components = comp;
            }
        }
        //Don't serialized timeline if it comes from prefab base
        if(timeline!=null&&(instanceOf==null||!instanceOf.timeline?.isEqualTo(timeline))){
            ret.timeline=timeline.guid;
        }
        var ret_child_registry=(!wasRoot||instanceOf==null)?null:relevant_children.map(e->{return {child:e.guid, parent:e.parent.guid.toRelative(this), index:e.parent.getIndexOfChild(e)}});
        if(ret_child_registry?.length>0){
            ret.child_registry=ret_child_registry;
        }
        return ret;
    }
    public static function FromSerialized(parent:IHasReference, entity:SerializedEntity):Entity{
        var new_entity = new Entity(null, null, null, Reference.SKIP_REGISTRATION);
        new_entity.loadFromSerialized(parent, entity);
        return new_entity;
    }

    public static function clone(instance:Entity, base:Entity){
        return instance.copy(base.guid);
    }

    public function copy(prefix:ThingID):Entity{
        var n = new Entity(getRoot(), this.name, [], [{guid:prefix}, this]);
        n.children_base_component=this.children_base_component;
        n.children_base_entity=this.children_base_entity;
        n.instanceOf=this.instanceOf;
        if(this.instanceOf!=null){
            n.isFromInstance=true;
        }
        for(c in this.components){
            n.addComponent(c);
        }
        for(key=>value in this.property_values){
            n.setValue(getRoot().unsafeGet(key), value);
        }
        n.timeline=this.timeline;
        for(c in this.children){
            n.addChild(c.copy(prefix));
        }
        return this;
    }

    function get_timeline(){
        if(this.timeline!=null) return this.timeline;
        if(instanceOf!=null){
            if(instanceOf.timeline!=null){
                return instanceOf.timeline;
            }
        }
        return null;
    }

    public static function CreateInstance(parent:IHasReference, entity:Entity, ?overrides:Array<Override>, ?name:String):Entity{
        var ancestor = parent.reference;
        while(ancestor.type!=ROOT){
            if(ancestor.type==ENTITY){
                var ent:Entity = ancestor.resolve();
                if(ent.guid==entity.guid||ent.instanceOf?.guid==entity.guid){
                    Util.log.error('Tried to create instance of $entity in $parent, but it would create a cyclic dependency.');
                    return new Entity(parent, "InvalidEntity");
                }
            }
            ancestor = ancestor.parent;
        }
        var instance = new Entity(parent, name??('${entity.name}_${Util.name_tail()}'));
        instance.instantiate(entity, overrides);
        return instance;
    }

    override public function loadFromSerialized(parent:IHasReference, data:Dynamic, ?id_prefix:String) {
        var d:SerializedEntity = data;
        var prefix = id_prefix!=null?'${id_prefix}:':'';
        this.guid = prefix+d.guid;
        setReference(ENTITY(this), parent); 
        
        this.name = d.name;
        this.dependencies = [];
        this.overrides = [];
        this.components = [];
        this.property_values = [];
        var root = this.getRoot();
        if(d.dependencies!=null){
            for(dep in d.dependencies){
                dependencies.push(Dependency.FromSerialized(dep));
            }
        }
        if(d.properties!=null){
            for(p in d.properties){
                property_values.set(p.definition, PropertyDef.DeserializeValue(p.value));
            }
        }
        if(d.components!=null){
            for(pl in d.components){
                var list:Component = root.getThing(COMPONENT, pl);
                if(list==null){
                    Util.log.error('Unable to find prop list $pl for $this.');
                    return;
                }
                components.push(list);
            }
        }
        if(d.children_base_entity!=null){
            children_base_entity=root.getThing(ENTITY, d.children_base_entity);
            if(children_base_entity==null){
                Util.log.error('Failed to load base entity prefab ${d.children_base_entity} for $this.');
            }
        }
        else if(d.children_base_component!=null){
            children_base_component=parent.reference.getRoot().getThing(COMPONENT, d.children_base_component);
            if(children_base_component==null){
                Util.log.error('Failed to load base prop definition ${d.children_base_component} for $this.');
            }
        }
        if(d.children!=null){
            for(c in d.children){
                var child:Entity;
                var tid=prefix+c.guid;
                if(root.hasThing(tid)){
                    child = root.getThing(ENTITY, prefix+c.guid);
                }
                else{
                    child = new Entity(null, null, null, Reference.SKIP_REGISTRATION);
                }
                child.loadFromSerialized(reference, c, id_prefix);
                addChild(child);
            }
        }
        if(d.base_guid!=null){
            var prefab:Entity = root.getThing(ENTITY, d.base_guid);
            for(o in d.overrides??[]){
                overrides.push(Override.FromSerialized(o));
            }
            instantiate(prefab, [], d.child_registry);
        }
        if(d.timeline!=null){
            this.timeline=root.getThing(TIMELINE, d.timeline);
        }
    }

    public function destroy(){
        for(c in children){
            c.destroy();
        }
        getRoot().removeThing(this);
    }

    function instantiate(prefab:Entity, ?new_overrides:Array<Override>, ?new_children:Array<ChildRegistryEntry>){
        if(prefab==null){
            Util.log.error('Failed to instantiate $this due to unresolvable reference!');
            return;
        }
        this.instanceOf=prefab;
        this.children_base_component = prefab.children_base_component;
        this.children_base_entity = prefab.children_base_entity;
        //If reversed the iteration here, could support prefab overrides at various levels
        //Though currently don't have sparse save structure to support it.
        for(component in prefab.components){
            this.addComponent(component);
        }
        for(child in prefab.children??[]){
            var existing_child = this.children.find(c->c.guid==[this, child]);
            if(existing_child!=null){
                existing_child.remove();
            }
            var new_child = new Entity(this);
            new_child.loadFromSerialized(this, child.serialize(), this.guid);

            new_child.skipSerialization=true;
            var res = this.addChild(new_child);
            if(!res){
                Util.log.error('Failed to reparent $new_child from $prefab onto $this!');
            }
        }
        var all_children = this.getChildrenRecursive(true);
        for(overr in new_overrides??[]){
            var def:PropertyDef = getRoot().getThing(PROPERTYDEF, overr.def_guid);
            if(def==null){
                Util.log.warn('$this tried to override a prop with def ${overr.def_guid} but it was not found.');
                continue;
            }

            if(overr.parent_guid==Reference.THIS){
                setValue(def, overr.value);
                continue;
            }

            var target:Entity = all_children.find(c->c.guid.unInstancedID==overr.parent_guid);//overr.parent_guid==Reference.THIS||this.guid==overr.parent_guid?this:this.getChildrenRecursive().find(c->c.guid.unInstancedID==overr.parent_guid);
            if(target==null){
                Util.log.warn('$this tried to override a prop on ${overr.parent_guid} but it was not found among children.');
                continue;
            }

            overrides.push(overr);
        }
        var prefab_children = prefab.getChildrenRecursive();
        // TODO Redirect REFS by walking components of each child
        // var prefab_properties = prefab.getPropertiesRecursive();
        // for(p in this.getPropertiesRecursive()){
        //     switch p.value {
        //         default:
        //         case REF(v):
        //             if(prefab_children.exists(c->c.guid==v)){
        //                 p.value=REF('${this.guid}:$v');
        //             }
        //             else if(v==prefab.guid){
        //                 p.value=REF(this.guid);
        //             }
        //         case REFS(v):
        //             var new_ref = [];
        //             var changed = false;
        //             for(ov in v){
        //                 if(prefab_children.exists(c->c.guid==ov)){
        //                     new_ref.push('${this.guid}:$ov');
        //                     changed=true;
        //                 }
        //                 else if(ov==prefab.guid){
        //                     new_ref.push(this.guid);
        //                     changed=true;
        //                 }
        //                 else{
        //                     new_ref.push(ov);
        //                 }
        //             }
        //             if(changed){
        //                 p.value = REFS(new_ref);
        //             }
        //     }
        // }
        for(c in all_children){
            if(prefab_children.exists(child->child.guid==c.guid.unInstancedID)){
                c.isFromInstance=true;
            }
        }
        if(new_children!=null){
            for(nc in new_children){
                var tc = this.children.find(c->c.guid.unInstancedID==nc.child);
                var p:Entity = all_children.find(c->c.guid==nc.parent.resolveThis(this)||c.guid.unInstancedID==nc.parent);//this.reference.getRoot().getThing(ENTITY, nc.parent.resolveThis(this));
                if(tc!=null&&p!=null){
                    this.removeChild(tc);
                    var res = p.addChildAt(tc, nc.index);
                    if(!res){ //TODO Investigate if we need to unload constructs and only load from stub when editing!
                        Util.log.error('Failed to align child $tc in parent $p on $this when instantiating from prefab $prefab.');
                    }
                }
                else{
                    Util.log.error('Invalid child $nc in child registry (parent $p, entity $this, prefab $prefab).');
                }
            }
        }
    }

    public function canAcceptChild(child:Entity):Bool{
        if(this.children.exists(c->c.isEqualTo(child))){
            Util.log.verbose('Want to add $child to $this but it is already there.');
            return false;
        }
        if(this.children_base_entity!=null){
            if(child.instanceOf?.guid!=children_base_entity.guid){
                Util.log.verbose('Want to add $child to $this but parent is constrained to instances of $children_base_entity');
                return false;
            }
        }
        else if(this.children_base_component!=null){
            if(!child.hasComponentByGUID(this.children_base_component.guid)){
                Util.log.verbose('Want to add $child to $this but parent is constrained to children with component $children_base_component');
                return false;
            }
        }
        return true;
    }

    /**
        Adds child safely, updating references.
        Removes from old parent if needed.
        False if child could not be added. 
        True otherwise. 
    **/
    public function addChild(child:Entity):Bool{
        if(!canAcceptChild(child)) return false;
        child.parent?.removeChild(child);
        child.reference.adopt(this);
        this.children.push(child);
        calculateDependencies();
        return true;
    }

    public function addChildAt(child:Entity, index:Int):Bool{
        if(!canAcceptChild(child)) return false;
        child.parent?.removeChild(child);
        child.reference.adopt(this);
        children.insert(index, child);
        calculateDependencies();
        return true;
    }

    /**
        Removes from parent AND from root. This kills the Entity.
    **/
    public function remove(){
        parent.removeChild(this);
        reference.getRoot().removeThing(this);
    }

    function get_parent():Entity{
        if(reference.parent!=null&&reference.parent.type==ENTITY){
            return reference.parent.resolve();
        }
        return null;
    }

    public function removeChild(e:Entity){
        return this.children.remove(e);
        calculateDependencies();
    }

    public function getChildAt(index:Int):Entity{
        if(children.length>=index){
            return children[index];
        }
        Util.log.error('No child at index $index in $this.');
        return null;
    }

    public function getIndexOfChild(e:Entity){
        return children.indexOf(e);
    }

    public function replaceChild(old_child:Entity, new_child:Entity):Bool{
        if(!children.exists(c->c.isEqualTo(old_child))){
            Util.log.error('$old_child not a child of $this to replace with $new_child.');
            return false;
        }
        var pos = children.indexOf(old_child);
        children.remove(children.find(c->c.isEqualTo(old_child)));
        return addChildAt(new_child, pos);
    }

    public function isComponentFromPrefab(component:Component){
        if(isFromInstance||instanceOf!=null){
            var base:Entity = instanceOf??getRoot().unsafeGet(this.guid.unInstancedID);
            if(base.hasComponentByGUID(component.guid)){
                return true;
            }
        }
        return false;
    }

    public function addComponent(component:Component){
        if(component.base&&this.components.exists(c->c.base)){
            Util.log.warn('Tried to add $component to $this but it already has base component ${getBaseComponent()}');
            return;
        }
        if(!this.components.exists(pl->pl.guid==component.guid)){
            for(req in component.requirements??[]){
                addComponent(req);
            }
            this.components.push(component);
        }
    }

    public function removeComponent(component:Component){
        if(this.instanceOf?.components?.exists(l->l.guid==component.guid)){
            return; //No delete parent lists...
        }
        if(this.components.remove(this.components.find(l->l.guid==component.guid))){
            for(p in component.definitions){
                removeProperty(p);
            }
        }
        calculateDependencies();
    }

    public function removeProperty(e:PropertyDef){
        property_values.remove(e.guid);
    }

    public function hasPropByName(name:String):Bool{
        for(c in components){
            if(c.getDefByName(name)!=null){
                return true;
            }
        }
        return false;
    }
    public function hasPropByGUID(guid:ThingID):Bool{
        for(c in components){
            if(c.hasDefByGUID(guid)){
                return true;
            }
        }
        return false;
    }
    public function hasPropByDef(def:PropertyDef):Bool{
        for(c in components){
            for(d in c.definitions){
                if(d.isEqualTo(def)){
                    return true;
                }
            }
        }
        return false;
    }
    public function hasComponentByName(name:String):Bool{
        for(c in components){
            if(c.name==name){
                return true;
            }
        }
        return false;
    }
    public function getComponentByName(name:String):Component{
        for(c in components){
            if(c.name==name){
                return c;
            }
        }
        return null;
    }
    public function hasComponentByGUID(guid:ThingID):Bool{
        for(c in components){
            if(c.guid==guid){
                return true;
            }
        }
        return false;
    }
    public function getComponentByGUID(guid:ThingID):Component{
        for(c in components){
            if(c.guid==guid){
                return c;
            }
        }
        return null;
    }
    public function getBaseComponent():Component{
        for(c in components){
            if(c.base){
                return c;
            }
        }
        return null;
    }

    override function calculateDependencies(){
        dependencies=[];        
        if(instanceOf!=null){
            instanceOf.assertDependency(dependencies);
        }
        if(children_base_entity!=null){
            children_base_entity.assertDependency(dependencies);
        }
        else if(children_base_component!=null){
            var cid:CoreComponent = children_base_component.guid;
            if(cid==NOT_CORE){
                children_base_component.assertDependency(dependencies);
            }
        }
        for(c in components){
            var cid:CoreComponent = c.guid;
            if(cid==NOT_CORE){
                c.assertDependency(dependencies);
            }
        }
        for(c in children){
            c.calculateDependencies();
            for(d in c.dependencies){
                if(!dependencies.exists(dep->dep.isEqualTo(d))){
                    dependencies.push(d);
                }
            }
        }
        if(timeline!=null){
            timeline.assertDependency(dependencies);
        }
    }
}