package thinglib;

import thinglib.property.Property.PropertyValue;
import thinglib.property.PropertyDef;
import thinglib.component.Entity;
import thinglib.storage.Reference.ReferenceValue;
import thinglib.Util.ThingID;
import hxsignal.impl.Signal3;

var entityRegistered:Signal3<ThingScape, ThingID, ReferenceValue> = new Signal3();
var entityUnregistered:Signal3<ThingScape, ThingID, ReferenceValue> = new Signal3();
var propertyValueChanged:Signal3<Entity, PropertyDef, PropertyValue> = new Signal3();