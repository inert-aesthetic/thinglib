package thinglib.property;

import thinglib.Util.ThingID;
import thinglib.storage.StorageTypes.SerializedOverride;
import thinglib.property.Property.PropertyValue;

class Override{
    /**
        The ID of the actual entity holding the property
    **/
    public var parent_guid:ThingID;
    /**
        The ID of the property definition that this override targets
    **/
    public var def_guid:ThingID;
    public var value:PropertyValue;
    public function new(parent:ThingID, definition:ThingID, value:PropertyValue){
        this.parent_guid = parent;
        this.def_guid = definition;
        this.value = value;
    }

    public function serialize(isRoot:Bool=true):SerializedOverride{
        return {parent_guid:parent_guid, def_guid:def_guid, value:PropertyDef.SerializeValue(value)};
    }

    public function isSameTargetAs(other:Override):Bool{
        return other.def_guid == this.def_guid && other.parent_guid == this.parent_guid;
    }

    public static function FromSerialized(data:SerializedOverride):Override{
        return new Override(data.parent_guid, data.def_guid, PropertyDef.DeserializeValue(data.value));
    }
}