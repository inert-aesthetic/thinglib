package thinglib.timeline;

import thinglib.storage.Reference;
import thinglib.storage.Dependency;
import uuid.Uuid;
import thinglib.storage.Reference.IHasReference;
import thinglib.property.PropertyDef;
import thinglib.storage.StorageTypes.SerializedPropertyValue;
import thinglib.Util.ThingID;
import thinglib.property.Property;
import thinglib.component.Entity;
using Lambda;

class Timeline extends Thing{
    public var states(default, null):Array<TimelineState>;
    public var defaultState(get, set):TimelineState;
    var _defaultState:String="Default";
    public function new(parent:IHasReference, name:String="", guid:String=null){
        this.name = name;
        this.extension = Consts.FILENAME_TIMELINE;
        this.guid=guid??Uuid.short();
        super(TIMELINE, parent);
    }
    override public function serialize(isRoot:Bool=true, ?ancestorDependencies:Array<Dependency>):SerializedTimeline{
        var ret:SerializedTimeline = {name:name, guid:guid, states: states?.map(s->s?.serialize())};
        if(_defaultState!="Default"){
            ret.defaultState=_defaultState;
        }
        return ret;
    }
    public static function FromSerialized(parent:IHasReference, data:SerializedTimeline):Timeline{
        
        var ret = new Timeline(null, null, Reference.SKIP_REGISTRATION);
        ret.loadFromSerialized(parent, data);
        return ret;
    }
    override public function loadFromSerialized(parent:IHasReference, raw:Dynamic, ?id_prefix:String):Void{
        var data:SerializedTimeline = raw;
        this.name = data.name;
        this.guid = data.guid;
        setReference(TIMELINE(this), parent);
        states = data.states?.map(s->TimelineState.FromSerialized(this, s));
        if(data.defaultState!=null){
            _defaultState=data.defaultState;
        }
        else{
            _defaultState="Default";
        }
    }
    function get_defaultState(){
        for(s in states){
            if(s.name==_defaultState){
                return s;
            }
        }
        return null;
    }
    function set_defaultState(to:TimelineState){
        _defaultState=to.name;
        for(s in states){
            if(s.name==to.name){
                return to;
            }
        }
        states.push(to);
        return to;
    }
    public function addState(name:String, frames:Int){
        states??=[];
        var state_dups = 0;
        var state_name = name;
        while(states.exists(s->s.name==state_name)){ //ensure unique name
            state_dups++;
            state_name=name+state_dups;
        }
        var new_state = new TimelineState(this, state_name, frames, STOP);
        states.push(new_state);
        return new_state;
    }
    public function getState(name:String){
        var ret = states?.find(s->s.name==name);
        if(ret==null){
            Util.log.error('Unable to find state named $name.');
        }
        return ret;
    }
    public static function Create(parent:Entity, ?name:String){
        var ret = new Timeline(parent, name??(parent.name+'_'+Uuid.short().substr(0, 4)));
        ret.defaultState = ret.addState("Default", 60);
        return ret;
    }
}

class TimelineState{
    var timeline:Timeline;
    public var name:String;
    public var frames:Int;
    public var tracks:Array<TimelineTrack> = [];
    public var onEnd:TimelineStateEndBehavior = STOP;
    public function new(timeline:Timeline, name:String, frames:Int, onEnd:TimelineStateEndBehavior){
        this.timeline=timeline;
        this.name=name;
        this.frames=frames;
        this.onEnd=onEnd;
    }
    public function serialize():SerializedTimelineState{
        return {name: name, tracks: tracks?.map(t->t?.serialize()), frames: frames, onEnd: switch onEnd {
            case STOP:{type:"STOP"};
            case LOOP:{type:"LOOP"};
            case GO_TO_FRAME(frame):{type:"FRAME",value:frame};
            case GO_TO_STATE(state):{type:"STATE",value:state};
        }};
    }
    public function addTrack(prop:PropertyDef, ?offset:TimelineOffsetMethod = ABSOLUTE){
        tracks??=[];
        if(tracks?.exists(t->t.target==prop.guid)){
            Util.log.error('Tried to add track for $prop but there already is one on state $name.');
            return null;
        }
        var ret = TimelineTrack.Create(this.timeline, this, prop.guid, offset);
        tracks.push(ret);
        return ret;
    }
    public function removeTrack(track:TimelineTrack) {
        tracks.remove(track);
    }
    public static function FromSerialized(timeline:Timeline, data:SerializedTimelineState):TimelineState{
        var ret = new TimelineState(timeline, data.name, data.frames, switch data.onEnd?.type {
            case "STOP":STOP;
            case "LOOP":LOOP;
            case "FRAME":GO_TO_FRAME(data.onEnd?.value??0);
            case "STATE":GO_TO_STATE(data.onEnd?.value??"Default");
            default: STOP;
        });
        ret.tracks=data.tracks?.map(t->TimelineTrack.FromSerialized(timeline, ret, t));
        return ret;
    }
    public function getTrackFor(property:PropertyDef):TimelineTrack{
        return tracks.find(t->t.target==property.guid);
    }
}

class TimelineTrack{
    var timeline:Timeline;
    var state:TimelineState;
    public var target:ThingID;
    public var offset:TimelineOffsetMethod;
    var keyframes:Map<Int, TimelineKeyframe>; 
    public function new(timeline, state, target, offset:TimelineOffsetMethod){
        this.timeline=timeline;
        this.target=target;
        this.state=state;
        this.keyframes=[];
        this.offset=offset;
    }
    public function serialize():SerializedTimelineTrack{
        var frames =keyframes!=null?[for (index => value in keyframes) {
            value.serialize(index);
        }]:[];
        frames.sort((a,b)->a.frame<b.frame?-1:a.frame>b.frame?1:0);
        return{target:target, keyframes:frames, offset:offset};
    }
    public static function FromSerialized(timeline:Timeline, state:TimelineState, data:SerializedTimelineTrack):TimelineTrack{
        var ret = new TimelineTrack(timeline, state, data.target, data.offset);
        for(k in data.keyframes){
            if(k.frame==0) continue; //don't serialize first frame (change this for non-bound tracks)
            ret.keyframes.set(k.frame, TimelineKeyframe.FromSerialized(k));
        }
        return ret;
    }
    public function getKeyframe(frame:Int){
        return keyframes.get(frame);
    }
    public function getAllKeyframes():Array<TimelineIndexedKeyframe>{
        var ret:Array<TimelineIndexedKeyframe> = [];
        for(frame=>data in keyframes){
            ret.push({frame: frame, keyframe: data});
        }
        return ret;
    }
    public function getNextKeyframe(frame:Int):TimelineIndexedKeyframe{
        var i=frame+1;
        while(i<state.frames){
            if(keyframes.exists(i)){
                return {frame:i, keyframe:keyframes.get(i)};
            }
            i++;
        }
        return null;
    }
    public function getPreviousKeyframe(frame:Int):TimelineIndexedKeyframe{
        var i=frame-1;
        while(i>0){
            if(keyframes.exists(i)){
                return {frame:i, keyframe:keyframes.get(i)};
            }
            i--;
        }
        return null;
    }
    public function addKeyframe(frame:Int, value:PropertyValue, ?interpolation:InterpolationMethod=NONE){
        if(keyframes.get(frame)!=null){
            Util.log.warn('Tried to add frame at $frame but there is already one there.');
            return null;
        }
        var new_frame = new TimelineKeyframe(value, interpolation);
        keyframes.set(frame, new_frame);
        return new_frame;
    }
    public function removeKeyframe(frame){
        keyframes.remove(frame);
    }
    public function tryMoveKeyframe(old_frame, new_frame){
        if((!keyframes.exists(old_frame))||keyframes.exists(new_frame)){
            return false;
        }
        var kf = keyframes.get(old_frame);
        keyframes.remove(old_frame);
        keyframes.set(new_frame, kf);
        return true;
    }
    public static function Create(timeline, state, target, offset){
        var ret = new TimelineTrack(timeline, state, target, offset);
        return ret;
    }
}

class TimelineKeyframe{
    public var value(get, set):PropertyValue;
    var _value:PropertyValue;
    public var interpolation:InterpolationMethod; //How to get to this value from the previous frame
    public function new(value, ?interpolation=NONE){
        this.value=value;
        this.interpolation=interpolation;
    }

    public function serialize(frame:Int):SerializedTimelineKeyframe{
        return {frame:frame, value:PropertyDef.SerializeValue(value), interpolation:interpolation};
    }

    function get_value(){
        return _value;
    }

    function set_value(to:PropertyValue){
        _value = to;
        return _value;
    }

    public static function FromSerialized(data:SerializedTimelineKeyframe):TimelineKeyframe{
        var ret = new TimelineKeyframe(PropertyDef.DeserializeValue(data.value), data.interpolation);
        return ret;
    }
}

enum abstract InterpolationMethod(String) to String{
    var NONE; // Snap to value on frame
    var LINEAR; // Smoothly
    // Later we add cubic, etc.
    public static function createAll():Array<InterpolationMethod>{
        return [NONE, LINEAR];
    }
}

enum abstract TimelineOffsetMethod(String) from String to String{
    var ABSOLUTE; //Frame value overrides underlying value.
    var RELATIVE; //Frame value is added to underlying value.
}

enum TimelineStateEndBehavior{
    STOP;
    LOOP;
    GO_TO_FRAME(frame:Int);
    GO_TO_STATE(state:String);
}

typedef TimelineIndexedKeyframe={
    frame:Int,
    keyframe:TimelineKeyframe
}

typedef SerializedTimeline={
    name:String,
    guid:String,
    states:Array<SerializedTimelineState>,
    ?defaultState:String
}

typedef SerializedTimelineState={
    name:String,
    frames:Int,
    tracks:Array<SerializedTimelineTrack>,
    onEnd:SerializedTimelineStateEndBehavior
}

typedef SerializedTimelineTrack={
    target:ThingID,
    keyframes:Array<SerializedTimelineKeyframe>,
    offset:TimelineOffsetMethod
}

typedef SerializedTimelineKeyframe={
    frame:Int,
    value:SerializedPropertyValue,
    interpolation:InterpolationMethod
}

typedef SerializedTimelineStateEndBehavior={
    type:String,
    ?value:Dynamic
}
