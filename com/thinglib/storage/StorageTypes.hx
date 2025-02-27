package thinglib.storage;

import thinglib.timeline.Timeline.SerializedTimeline;
import thinglib.Util.ThingID;
import thinglib.storage.Reference.ReferenceType;
import thinglib.property.PropertyDef.PropertyType;


class StorageTypes{}

typedef SerializedDependency = {
    type:ReferenceType,
    guid:String,
    path:String
}

//Construct storage
typedef SerializedEntity = {
    ?timeline:ThingID,
    ?dependencies:Array<SerializedDependency>,
    ?name:String, 
    ?properties:Array<SerializedProperty>, 
    ?children:Array<SerializedEntity>, 
    ?guid:String,
    ?overrides:Array<SerializedOverride>,
    ?base_guid:String, //guid of the entity that this is an instance of
    ?child_registry:Array<ChildRegistryEntry>,
    ?children_base_entity:String,
    ?children_base_component:String,
    ?components:Array<String>,
};

typedef ChildRegistryEntry = {
    child:ThingID,
    parent:ThingID,
    index:Int
}

typedef SerializedPropertyDef = {
    name:String, 
    guid:String, 
    default_value:SerializedPropertyValue, 
    ?min:SerializedPropertyValue, 
    ?max:SerializedPropertyValue, 
    ?step:SerializedPropertyValue, 
    ?ref_base_type:String,
    type:String, 
    ?extra:String, 
    ?documentation:String,
    ?options:Array<String>,
    ?timeline_controllable:Bool
};
typedef SerializedComponent = {
    name:String, 
    guid:String,
    definitions:Array<SerializedPropertyDef>,
    ?dependencies:Array<SerializedDependency>,
    ?user_selectable:Bool,
};
typedef SerializedProperty = {
    definition:ThingID, 
    value:SerializedPropertyValue
};
typedef SerializedPropertyValue = {
    type:PropertyType,
    value:Dynamic
}

typedef SerializedOverride = {
    parent_guid:String,
    def_guid:String,
    value:SerializedPropertyValue
}