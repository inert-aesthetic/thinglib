package thinglib.component;

import thinglib.timeline.Timeline.TimelineStateEndBehavior;
import thinglib.timeline.Timeline.TimelineState;
import thinglib.property.core.CoreComponents.CoreComponentRegion;
import thinglib.property.core.CoreComponents.CoreComponentPosition;
import thinglib.property.core.CoreComponents.CoreComponentEdge;
import thinglib.property.core.CoreComponents.CoreComponentTimelineControl;
import thinglib.property.core.CoreComponents.CoreComponent;
import pasta.Rect;
import thinglib.storage.Reference;
import pasta.Segment;
import thinglib.component.Entity;
import pasta.Vect;
using thinglib.component.util.EntityTools;
using thinglib.component.util.PropertyValueTools;
using Lambda;

// #region Node
@:forward
abstract Node(Position) to Entity to Position{
    @:from
    static function fromEntity(entity:Entity){
        if(!entity.isNode()){
            Util.log.error('Tried to access ${entity} as Node.');
            //return null;
        }
        return new Node(entity);
    }

    function new(entity:Entity){
        this=entity;
    }
}

@:forward
abstract Position(Entity) from Node from Region from Path to Entity{
    public var local_position(get, set):Vect;
    public var global_position(get, set):Vect;
    public var guid(get, never):String;
    public var x(get, set):Float;
    public var y(get, set):Float;
    
    function new(entity:Entity){
        this=entity;
    }
    function get_guid(){
        return this.guid;
    }
    function get_local_position(){
        return new Vect(get_x(), get_y());
    }
    function get_global_position(){
        var ret = get_local_position();
        var p = this.parent;
        while(p!=null){
            if(p.hasPosition()){
                var pn = p.asPosition();
                ret = ret.add(pn.get_local_position());
            }
            p=p.parent;
        }
        return ret;
    }
    function set_global_position(to:Vect){
        var ret = to.copy();
        var p = this.parent;
        while(p!=null){
            if(p.hasPosition()){
                var pn = p.asPosition();
                ret = ret.sub(pn.get_local_position());
            }
            p=p.parent;
        }
        set_local_position(ret);
        return to;
    }
    public function getGlobalPositionForFrame(f:Int){
        if(!this.hasTimelineController()) return get_global_position();
        var tc = this.asTimelineControlled();
        var ret =   new Vect(
                        this.getValueForFrame(CoreComponentPosition.x_def, tc.current_state, f).floatValue(),
                        this.getValueForFrame(CoreComponentPosition.y_def, tc.current_state, f).floatValue()
                    );
        var p = this.parent;
        while(p!=null){
            if(p.hasPosition()){
                var pn = p.asPosition();
                ret = ret.add(pn.get_local_position());
            }
            p=p.parent;
        }
        return ret;
    }
    function get_x(){
        return this.getValue(CoreComponentPosition.x_def).floatValue();
    }
    function get_y(){
        return this.getValue(CoreComponentPosition.y_def).floatValue();
    }
    function set_x(to){
        this.setValue(CoreComponentPosition.x_def, FLOAT(to));
        return to;
    }
    function set_y(to){
        this.setValue(CoreComponentPosition.y_def, FLOAT(to));
        return to;
    }

    function set_local_position(to){
        set_x(to.x);
        set_y(to.y);
        return to.copy();
    }

    @:from
    static function fromNode(node:Node){
        return new Position(node);
    }
    @:from
    static function fromEntity(entity:Entity){
        if(!entity.hasPosition()){
            Util.log.error('Tried to access ${entity} as Position.');
            //return null;
        }
        return new Position(entity);
    }
    @:to
    function toVect():Vect{
        return local_position;
    }

    public function containedByRect(position:Vect, width:Float=0, height:Float=0):Bool{
        var g = global_position;
        return g.x>position.x&&g.x<position.x+width&&g.y>position.y&&g.y<position.y+height;
    }

    public function containsPoint(position:Vect, buffer:Float=0):Bool{
        return global_position.rawDistanceTo(position)<buffer*buffer;
    }

    public function distanceToCenter(position:Vect):Float{
        return global_position.distanceTo(position);
    }

    @:to
    function toRegion():Region{
        if(this.isRegion()){
            return this;
        }
        Util.log.error('Tried to use $this as Region.');
        return null;
    }
}
// #endregion
// #region Edge
@:forward
abstract Edge(Entity) to Entity {
    public var a(get, set):Node;
    public var b(get, set):Node;
    public var isComplete(get, never):Bool;

    function new(entity:Entity){
        this=entity;
    }

    function get_isComplete():Bool{
        if(
            this.getValue(CoreComponentEdge.a_def).stringValue()==Reference.EMPTY_ID
            ||
            this.getValue(CoreComponentEdge.b_def).stringValue()==Reference.EMPTY_ID
        ){
            return false;
        }
        return get_a()!=null&&get_b()!=null;
    }

    function get_a(){
        var ret = this.getValue(CoreComponentEdge.a_def).entityValue(this);
        if(ret==null){
            Util.log.warn('Tried to access "a" of $this, but it is empty.');
            return null;
        }
        return ret.asNode();
    }
    function get_b(){
        var ret = this.getValue(CoreComponentEdge.b_def).entityValue(this);
        if(ret==null){
            Util.log.warn('Tried to access "b" of $this, but it is empty.');
            return null;
        }
        return ret.asNode();
    }
    function set_a(to:Node):Node{
        this.setValue(CoreComponentEdge.a_def, REF(cast(to, Entity).guid));
        return to;
    }
    function set_b(to:Node):Node{
        this.setValue(CoreComponentEdge.b_def, REF(cast(to, Entity).guid));
        return to;
    }

    public function isPointOnSeg(p:Vect):Bool {
        if(!isComplete) return false;
        var ag = a.global_position;
        var bg = b.global_position;
		var u:Float = ((p.x - ag.x) * (bg.x-ag.x) + (p.y - ag.y) * (bg.y-ag.y)) / ag.rawDistanceTo(bg);
		if (u > 0.0001 && u < 1) {
			return true;
		}
		return false;
	}

    public function getSegment():Segment{
        return new Segment(a.global_position, b.global_position);
    }

    public function distanceToPoint(p:Vect):Float {			
        if(!isComplete) return 999999;
        var ag = a.global_position;
        var bg = b.global_position;
		var u:Float = ((p.x - ag.x) * (bg.x-ag.x) + (p.y - ag.y) * (bg.y-ag.y)) / ag.rawDistanceTo(bg);
		
		var ix:Float = ag.x + u * (bg.x-ag.x);
		var iy:Float = ag.y + u * (bg.y-ag.y);
		
		var ixd:Float = ix-p.x;
		var iyd:Float = iy-p.y;
	
		return Math.sqrt(ixd*ixd+iyd*iyd);
	}
    
    @:from
    static function fromEntity(entity:Entity){
        if(entity.isEdge()){
            return new Edge(entity);
        }
        else{
            Util.log.error('Tried to access ${entity} as Edge.');
            return null;
        }
    }

    public function containedByRect(position:Vect, width:Float=0, height:Float=0):Bool{
        if(!isComplete) return false;
        var ag = a.global_position;
        var bg = b.global_position;
        return  (ag.x>position.x&&ag.y>position.y&&ag.x<position.x+width&&ag.y<position.y+height)
                &&
                (bg.x>position.x&&bg.y>position.y&&bg.x<position.x+width&&bg.y<position.y+height);
    }

    public function containsPoint(position:Vect, buffer:Float=0):Bool{
        if(!isComplete) return false;
        return isPointOnSeg(position)&&distanceToPoint(position)<buffer;
    }

    public function distanceToCenter(position:Vect):Float{
        if(!isComplete) return Math.POSITIVE_INFINITY;
        return getSegment().getPointByBalance(0.5).distanceTo(position);
    }
}
// #endregion
// #region Region
@:forward
abstract Region(Position) to Entity to Position{
    function new(entity:Entity){
        this=entity;
    }
    @:from
    static function fromEntity(entity:Entity){
        if(!entity.isRegion()){
            Util.log.error('Tried to access ${entity} as Region.');
            return null;
        }
        return new Region(entity);
    }
    public var width(get, set):Float;
    public var height(get, set):Float;
    public var rect(get, never):Rect;

    public var corners(get, never):Array<RegionCorner>;
    public var corner_map(get, never):Map<RegionCornerType, RegionCorner>;

    public var center(get, never):Vect;

    function get_rect():Rect{
        var p = this.local_position;
        return new Rect(p.x, p.y, p.x+get_width(), p.y+get_height());
    }

    function get_width():Float{
        return this.getValue(CoreComponentRegion.width_def).floatValue();
    }

    function get_height():Float{
        return this.getValue(CoreComponentRegion.height_def).floatValue();
    }

    function set_width(to:Float):Float{
        this.setValue(CoreComponentRegion.width_def, FLOAT(to));
        return to;
    }

    function set_height(to:Float):Float{
        this.setValue(CoreComponentRegion.height_def, FLOAT(to));
        return to;
    }

    private function get_corners():Array<RegionCorner>{
        var p = this.global_position;
        return [
            {position: p.copy(), corner: TOP_LEFT, region:this},
            {position: p.copy().addXY(width,0), corner: TOP_RIGHT, region:this},
            {position: p.copy().addXY(0, height), corner: BOTTOM_LEFT, region:this},
            {position: p.copy().addXY(width, height), corner: BOTTOM_RIGHT, region:this},
        ];
    }

    private function get_corner_map():Map<RegionCornerType, RegionCorner>{
        var p = this.global_position;
        var ret = new Map<RegionCornerType, RegionCorner>();
        ret.set(TOP_LEFT, {position: p.copy(), corner: TOP_LEFT, region:this});
        ret.set(TOP_RIGHT, {position: p.copy().addXY(width,0), corner: TOP_RIGHT, region:this});
        ret.set(BOTTOM_LEFT, {position: p.copy().addXY(0, height), corner: BOTTOM_LEFT, region:this});
        ret.set(BOTTOM_RIGHT, {position: p.copy().addXY(width,height), corner: BOTTOM_RIGHT, region:this});
        return ret;
    }

    public function getCorner(corner:RegionCornerType):RegionCorner{
        var p = this.asPosition().global_position;
        return switch corner {
            case TOP_LEFT: {position: p.copy(), corner: TOP_LEFT, region:this};
            case TOP_RIGHT: {position: p.copy().addXY(width,0), corner: TOP_RIGHT, region:this};
            case BOTTOM_LEFT: {position: p.copy().addXY(0, height), corner: BOTTOM_LEFT, region:this};
            case BOTTOM_RIGHT: {position: p.copy().addXY(width,height), corner: BOTTOM_RIGHT, region:this};
        }
    }

    public function setCorner(corner:RegionCornerType, value:Vect) {
        var bottom_right = getCorner(BOTTOM_RIGHT).position;
        var p = this.global_position;
        switch corner {
            case TOP_LEFT:
                set_width(bottom_right.x-value.x);
                set_height(bottom_right.y-value.y);
                this.global_position=value;
            case TOP_RIGHT:
                this.global_position=new Vect(p.x, value.y);
                set_width(value.x - p.x);
                set_height(bottom_right.y-value.y);
            case BOTTOM_LEFT:
                this.global_position=new Vect(value.x, p.y);
                set_height(value.y - p.y);
                set_width(bottom_right.x-value.x);
            case BOTTOM_RIGHT:
                set_width(value.x - p.x);
                set_height(value.y - p.y);
        }
    }

    private function get_center():Vect{
        var p =this.global_position;
        return new Vect(p.x + width/2, p.y+height/2);
    }

    public function contains(point:Vect):Bool{
        var p = this.global_position;
        return point.x>=p.x&&point.x<=p.x+width&&point.y>=p.y&&point.y<=p.y+height;
    }

    public function containsPoint(position:Vect, buffer:Float=0):Bool{
        return contains(position);
    }

    public function containedByRect(position:Vect, width:Float=0, height:Float=0):Bool{
        var ag = getCorner(TOP_LEFT).position;
        var bg = getCorner(BOTTOM_RIGHT).position;
        return  (ag.x>position.x&&ag.y>position.y&&ag.x<position.x+width&&ag.y<position.y+height)
                &&
                (bg.x>position.x&&bg.y>position.y&&bg.x<position.x+width&&bg.y<position.y+height);
    }

    public function distanceToCenter(position:Vect):Float{
        return get_center().distanceTo(position);
    }
}
typedef RegionCorner = {position:Vect, corner:RegionCornerType, region:Region};

enum RegionCornerType{
    TOP_LEFT;
	TOP_RIGHT;
	BOTTOM_LEFT;
	BOTTOM_RIGHT;
}

// #endregion

// #region Path
@:forward
abstract Path(Position) to Entity to Position{
    public var points(get, never):Array<Node>;
    function new(entity:Entity){
        this=entity;
    }
    @:from
    static function fromEntity(entity:Entity){
        if(!entity.baseIs(PATH)){
            Util.log.error('Tried to access ${entity} as Path.');
            return null;
        }
        return new Path(entity);
    }
    function get_points():Array<Node>{
        return this.children.Nodes();
    }

    @:to
    function toNode():Node{
        return this.asNode();
    }
}
// #endregion
// #region Tangible
@:forward
abstract Tangible(Entity) to Entity{
    function new(e:Entity){ 
        this = e;
    }

    inline function myType():CoreComponent{
        return this.getBaseComponent()?.guid??"";
    }

    public function containsPoint(position:Vect, buffer:Float):Bool{
        return switch myType() {
            case NODE, PATH:
               this.asPosition().containsPoint(position, buffer); 
            case EDGE:
                this.asEdge().containsPoint(position, buffer);
            case REGION:
                this.asRegion().containsPoint(position, buffer);
            default: false;
        }
    }

    public function containedByRect(topLeft:Vect, width:Float, height:Float):Bool{
        return switch myType() {
            case NODE, PATH:
                this.asPosition().containedByRect(topLeft, width, height);
            case EDGE:
                this.asEdge().containedByRect(topLeft, width, height);
            case REGION:
                this.asRegion().containedByRect(topLeft, width, height);
            default: false;
        }
    }

    public function distanceToCenter(position:Vect):Float{
        return switch myType() {
            case NODE, PATH:
                this.asPosition().distanceToCenter(position);
            case EDGE:
                this.asEdge().distanceToCenter(position);
            case REGION:
                this.asRegion().distanceToCenter(position);
            default: Math.POSITIVE_INFINITY;
        }
    } 

    @:from
    static function fromEntity(e:Entity):Tangible{
        if(!e.isTangible()){
            Util.log.warn('Tried to get $e as Tangible; it is not.');
            return null;
        }
        return new Tangible(e);
    }
}
// #endregion

// #region Timeline

@:forward 
abstract TimelineControlled(Entity) to Entity{
    public var frame(get, set):Int;
    public var current_state(get, never):TimelineState;
    public var on_end(get, set):TimelineStateEndBehavior;
    public var is_playing(get, set):Bool;
    function new(entity:Entity){
        this=entity;
    }
    function get_frame():Int{
        return this.getValue(CoreComponentTimelineControl.frame_def).intValue();
    }
    public function setState(to:String){
        if(this.timeline.states.exists(s->s.name==to)){
            this.setValue(CoreComponentTimelineControl.state_def, STRING(to));
        }
        else{
            Util.log.error('Tried to set state $to on $this but it does not exist.');
        }
    }
    function set_frame(to:Int):Int{
        this.setValue(CoreComponentTimelineControl.frame_def, INT(to));
        return to;
    }
    function get_current_state(){
        var s = this.getValue(CoreComponentTimelineControl.state_def).stringValue();
        return this.timeline?.getState(s);
    }
    function get_on_end(){
        return get_current_state()?.onEnd;
    }
    function set_on_end(to){
        var s = get_current_state();
        if(s!=null){
            return s.onEnd=to;
        }
        return null;
    }
    function get_is_playing(){
        return this.getValue(CoreComponentTimelineControl.playing_def).boolValue();
    }
    function set_is_playing(to:Bool){
        this.setValue(CoreComponentTimelineControl.playing_def, BOOL(to));
        return to;
    }
    @:from
    static function fromEntity(entity:Entity){
        if(!entity.hasComponentByGUID(CoreComponent.TIMELINE_CONTROL)){
            trace('Error: Tried to access ${entity} as TimelineControlled.');
            return null;
        }
        if(entity.timeline==null){
            trace('Warning: TimelineControlled $entity has no timeline.');
        }
        return new TimelineControlled(entity);
    }
}

// #endregion