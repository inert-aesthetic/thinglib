package thinglib.component.util;

import thinglib.property.PropertyDef;
import thinglib.property.Property.PropertyValue;
using StringTools;

class PropertyValueTools{

    public static function add(a:PropertyValue, b:PropertyValue):PropertyValue{
        return switch a {
            case INT(v): INT(v+intValue(b));
            case FLOAT(v): FLOAT(v+floatValue(b));
            default: b;
        }
    }
    public static function subtract(a:PropertyValue, b:PropertyValue):PropertyValue{
        return switch a {
            case INT(v): INT(v-intValue(b));
            case FLOAT(v): FLOAT(v-floatValue(b));
            default: b;
        }
    }

    public static function getValueAsDynamic(value:PropertyValue):Dynamic{
        return switch value {
            case INT(v): v;
            case FLOAT(v): v;
            case STRING(v): v;
            case BOOL(v): v;
            case COLOR(v): v;
            case SELECT(v): v;
            case MULTI(v): v;
            case REF(v): v;
            case REFS(v): v;
            case URI(v): v;
            case BLANK: null;
            case NONE: null;
        }
    }

    public static function intValue(value:PropertyValue):Int{
        return switch value {
            case INT(v): v;
            case FLOAT(v): Std.int(v);
            case STRING(v): Std.parseInt(v);
            case BOOL(v): v?1:0;
            case COLOR(v): v;
            case SELECT(v): v;
            default: 0;
        }
    }

    public static function floatValue(value:PropertyValue):Float{
        return switch value {
            case INT(v): v;
            case FLOAT(v): v;
            case STRING(v): Std.parseFloat(v);
            case BOOL(v): v?1:0; 
            case COLOR(v): v;
            case SELECT(v): v;
            default: 0;
        }
    }

    public static function stringValue(value:PropertyValue):String{
        return switch value {
            case INT(v): Std.string(v);
            case FLOAT(v): Std.string(v);
            case STRING(v): v;
            case URI(v): v;
            case BOOL(v): Std.string(v);
            case COLOR(v): "#"+v.hex(6);
            case REF(v): Std.string(v);
            case REFS(v): v.join(',');
            default: "";
        }
    }

    public function SelectStringValue(value:PropertyValue, definition:PropertyDef):String{
        return switch value {
            case SELECT(v): definition.options[v]??"";
            default:"";
        }
    }

    public function MultiStringArrayValue(value:PropertyValue, definition:PropertyDef):Array<String>{
        return switch value {
            case MULTI(v): v.map(o->definition.options[o]??"");
            default:[];
        }
    }

    public static function stringArrayValue(value:PropertyValue):Array<String>{
        return switch value {
            case REFS(v): v;
            default: [];
        }
    }

    public static function boolValue(value:PropertyValue):Bool{
        return switch value {
            case INT(v): v!=0;
            case FLOAT(v): v!=0;
            case STRING(v): v=="1"||v.toLowerCase()=="true";
            case BOOL(v): v;
            case COLOR(v): v!=0;
            default:  false;
        }
    }


    public static function intArrayValue(value:PropertyValue):Array<Int>{
        return switch value {
            default: [];
            case MULTI(v): v;
            case NONE: null;
        }
    }

    public static function entityValue(value:PropertyValue, parent:Entity):Entity{
        return switch value{
            case REF(v):  return parent.reference.getRoot().getThing(ENTITY, v);
            default: null;
        }
    }

    public static function entityArrayValue(value:PropertyValue, parent:Entity):Array<Entity>{
        return switch value{
            case REFS(v): return v.map(id->parent.reference.getRoot().getThing(ENTITY, id));
            default: null;
        }
    }
}