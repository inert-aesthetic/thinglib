package thinglib.property;
import thinglib.Util.ThingID;

enum PropertyValue{
    INT(v:Int);
    FLOAT(v:Float);
    STRING(v:String);
    BOOL(v:Bool);
    COLOR(v:Int);
    SELECT(v:Int);
    MULTI(v:Array<Int>);
    REF(v:ThingID);
    REFS(v:Array<ThingID>);
    URI(v:String);
    BLANK;
    NONE;
}