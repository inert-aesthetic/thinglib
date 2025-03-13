package thinglib.property.core;

import thinglib.Util.ThingID;
import thinglib.storage.Reference;

enum abstract CoreComponent(String) to String to ThingID{
    var POSITION = "core_position";
    var NODE = "core_node";
    var EDGE = "core_edge";
    var GROUP = "core_group";
    var REGION = "core_region";
    var PATH = "core_path";
    var TIMELINE_CONTROL = "core_timeline_control";
    var NOT_CORE = "not_core";
    function new(v:CoreComponent){
        this = fromString(v);
    }
    public static function createAll():Array<CoreComponent>{        
        return [POSITION, NODE, EDGE, GROUP, REGION, PATH, TIMELINE_CONTROL];
    }
    public static function isBase(c:CoreComponent):Bool{
        return switch(c){
            case NODE,EDGE,GROUP,REGION,PATH:true;
            default: false;
        }
    }

    @:from
    static function fromString(v:String):CoreComponent{
        return switch v {
            case POSITION: POSITION;
            case NODE: NODE;
            case EDGE: EDGE;
            case GROUP: GROUP;
            case REGION: REGION;
            case PATH: PATH;
            case TIMELINE_CONTROL: TIMELINE_CONTROL;
            default: NOT_CORE; 
        }
    }

    @:from
    static function fromThingID(v:ThingID):CoreComponent{
        return fromString(v);
    }
}

class CoreComponents{
    public static function initialize(root:IHasReference){
        var pos = new CoreComponentPosition(root);
        new CoreComponentNode(root, pos);
        new CoreComponentEdge(root);
        new CoreComponentGroup(root);
        new CoreComponentRegion(root, pos);
        new CoreComponentPath(root, pos);
        new CoreComponentTimelineControl(root);
    }
}

class CoreComponentTimelineControl extends Component{
    public static inline final FRAME = "core_timeline_control_frame";
    public static inline final STATE = "core_timeline_control_state";
    public static inline final PLAYBACK = "core_timeline_control_playback";
    public static inline final NAME = "Timeline Control";
    public static var frame_def:PropertyDef;
    public static var state_def:PropertyDef;
    public static var playing_def:PropertyDef;

    public function new(parent:IHasReference){
        super(parent, NAME, CoreComponent.TIMELINE_CONTROL);
        frame_def = new PropertyDef(this, "frame", INT, FRAME);
        state_def = new PropertyDef(this, "state", STRING, STATE);
        playing_def = new PropertyDef(this, "playing", BOOL, PLAYBACK);
        frame_def.timeline_controllable=false;
        state_def.timeline_controllable=false;
        playing_def.timeline_controllable=false;
        playing_def.default_value=BOOL(false);
        frame_def.minimum_value=INT(0);
        state_def.default_value=STRING("Default");
        this.definitions=[
            frame_def, state_def, playing_def
        ];
    }
}

class CoreComponentPosition extends Component{
    public static inline final X = "core_position_x";
    public static inline final Y = "core_position_y";
    public static inline final NAME = "Position";
    public static var x_def:PropertyDef;
    public static var y_def:PropertyDef;

    public function new(parent:IHasReference){
        super(parent, NAME, CoreComponent.POSITION);
        var x = x_def = new PropertyDef(this, "x", FLOAT, X);
        var y = y_def = new PropertyDef(this, "y", FLOAT, Y);
        x.default_value=FLOAT(0);
        y.default_value=FLOAT(0);
        this.definitions=[
            x, y
        ];
    }
}

class CoreComponentNode extends Component{
    public static inline final NAME = "Node";
    public function new(parent:IHasReference, position:Component){
        super(parent, NAME, CoreComponent.NODE);
        this.base=true;
        this.requirements=[position];
    }
}

class CoreComponentEdge extends Component{
    public static inline final B = "core_edge_b";
    public static inline final A = "core_edge_a";
    public static inline final NAME = "Edge";
    public static var a_def:PropertyDef;
    public static var b_def:PropertyDef;

    public function new(parent:IHasReference){
        super(parent, NAME, CoreComponent.EDGE);
        this.base=true;
        var a = a_def = new PropertyDef(this, "a", REF, A);
        var b = b_def = new PropertyDef(this, "b", REF, B);
        a.default_value=REF(Reference.EMPTY_ID);
        a.ref_base_type_guid = CoreComponent.NODE;
        b.default_value=REF(Reference.EMPTY_ID);
        b.ref_base_type_guid = CoreComponent.NODE;
        this.definitions=[
            a, b
        ];
    }
}

class CoreComponentGroup extends Component{
    public static inline final TYPE = "core_group_type";
    public static inline final NAME = "Group";

    public function new(parent:IHasReference){
        super(parent, NAME, CoreComponent.GROUP);
        this.base=true;
        var type = new PropertyDef(this, "type", REF, TYPE);
        type.default_value=REF(Reference.EMPTY_ID);
        this.definitions=[
            type
        ];
    }
}

class CoreComponentRegion extends Component{
    public static inline final HEIGHT = "core_region_height";
    public static inline final WIDTH = "core_region_width";
    public static inline final NAME = "Region";
    public static var width_def:PropertyDef;
    public static var height_def:PropertyDef;


    public function new(parent:IHasReference, position:Component){
        super(parent, NAME, CoreComponent.REGION);
        this.base=true;
        var width = width_def = new PropertyDef(this, "width", FLOAT, WIDTH);
        var height = height_def = new PropertyDef(this, "height", FLOAT, HEIGHT);
        width.default_value = FLOAT(0);
        height.default_value = FLOAT(0);
        this.definitions=[
            width, height
        ];

        this.requirements=[position];
    }
}

class CoreComponentPath extends Component{
    public static inline final NAME = "Path";
    public function new(parent:IHasReference, position:Component){
        super(parent, NAME, CoreComponent.PATH);
        this.base=true;
        this.requirements=[position];
    }
}