package thinglib;
#if(!macro)
import thinglib.property.Property.PropertyValue;
import thinglib.property.PropertyDef;
import thinglib.component.Entity;
import thinglib.storage.Reference.ReferenceValue;
import thinglib.Util.ThingID;
import hxsignal.impl.Signal3;


var entityRegistered:Signal3<ThingScape, ThingID, ReferenceValue> = new Signal3();
var entityUnregistered:Signal3<ThingScape, ThingID, ReferenceValue> = new Signal3();
var propertyValueChanged:Signal3<Entity, PropertyDef, PropertyValue> = new Signal3();
#else
class MockSignal3{
    public function new(){}
    public function emit(a:Dynamic, b:Dynamic, c:Dynamic){}
    public function connect(v:Dynamic){
        throw{
            trace("Shouldn't be connecting signals in macro!");
        }
    };
}
var entityRegistered = new MockSignal3();
var entityUnregistered = new MockSignal3();
var propertyValueChanged = new MockSignal3();
#end