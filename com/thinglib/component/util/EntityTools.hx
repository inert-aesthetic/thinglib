package thinglib.component.util;

import thinglib.component.Accessors.TimelineControlled;
import thinglib.Util.ThingID;
import thinglib.component.Accessors.Position;
import thinglib.property.core.CoreComponents.CoreComponent;
import thinglib.component.Accessors.Tangible;
import thinglib.component.Accessors.Edge;
import thinglib.component.Accessors.Region;
import thinglib.component.Accessors.Path;
import thinglib.component.Accessors.Node;
import pasta.Vect;
import pasta.Rect;
using Lambda;

class EntityTools{
    /**
        Gets array of all childrens' childrens' children etc, ordered like a flattened scene graph
    **/
    public static function getChildrenRecursive(root:Entity, ?includeRoot:Bool=false):Array<Entity>{
        var out = includeRoot?[root]:[];
        for(c in root.children){
            out.push(c);
            getChildrenRecursive(c).iter(g->out.push(g));
        }
        return out;
    }

    public static function findChildRecursive(root:Entity, childID:ThingID, ignoreInstance:Bool=false):Entity{
        for(c in root.children){
            if(ignoreInstance){
                if(c.guid.unInstancedID==childID){
                    return c;
                }
            }
            else{
                if(c.guid==childID){
                    return c;
                }
            }
            var ret = findChildRecursive(c, childID, ignoreInstance);
            if(ret!=null){
                return ret;
            }
        }
        return null;
    }

    public static function hasAncestor(child:Entity, suspect:Entity):Bool{
        var ancestor = child.parent;
        while(ancestor!=null){
            if(ancestor==suspect){
                return true;
            }
            ancestor = ancestor.parent;
        }
        return false;
    }

    public static function getNodesRecursive(root:Entity, includeRoot:Bool=false):Array<Node>{
        return Nodes(getChildrenRecursive(root, includeRoot));
    }
    public static function getEdgesRecursive(root:Entity, includeIncomplete:Bool=true, includeRoot:Bool=false):Array<Edge>{
        return Edges(getChildrenRecursive(root, includeRoot), includeIncomplete);
    }
    public static function getRegionsRecursive(root:Entity, includeRoot:Bool=false):Array<Region>{
        return Regions(getChildrenRecursive(root, includeRoot));
    }

    public static function getNodes(entity:Entity, includeRoot:Bool=false):Array<Node>{
        var ret = entity.children.filter(child->child.getBaseComponent().guid==CoreComponent.NODE).map(e->asNode(e));
        if(includeRoot) ret.push(entity);
        return ret;
    }
    public static function getRegions(entity:Entity, includeRoot:Bool=false):Array<Region>{
        var ret = entity.children.filter(child->child.getBaseComponent().guid==CoreComponent.REGION).map(e->asRegion(e));
        if(includeRoot) ret.push(entity);
        return ret;
    }
    public static function getEdges(entity:Entity, includeIncomplete:Bool=true, includeRoot:Bool=false):Array<Edge>{
        var ret = entity.children.filter(child->(child.getBaseComponent().guid==CoreComponent.EDGE)&&(includeIncomplete||asEdge(child).isComplete)).map(e->asEdge(e));
        if(includeRoot) ret.push(entity);
        return ret;
    }

    public static function getNodesInRect(entity:Entity, top_left:Vect, width:Float, height:Float, includeRoot=false):Array<Node>{
        var ret:Array<Node> = [];
        for(n in getNodes(entity, includeRoot)){
            var ng = n.global_position;
            if(ng.x>=top_left.x && ng.x<=top_left.x+width&&ng.y>=top_left.y && ng.y<=top_left.y+height){
                ret.push(n);
            }
        }
        return ret;
    }

    public static function getNodesInRectRecursive(entity:Entity, top_left:Vect, width:Float, height:Float, includeRoot:Bool=false):Array<Node>{
        var ret:Array<Node> = [];
        for(n in getNodesRecursive(entity, includeRoot)){
            var ng = n.global_position;
            if(ng.x>=top_left.x && ng.x<=top_left.x+width&&ng.y>=top_left.y && ng.y<=top_left.y+height){
                ret.push(n);
            }
        }
        return ret;
    }
    public static function getClosestNodeTo(entity:Entity, point:Vect, limit_distance:Float=-1, recurse:Bool=true, includeRoot:Bool=false):Node{
        var closest:Node = null;
        var range:Float = -1;
        for(n in (recurse?getNodesRecursive(entity, includeRoot):getNodes(entity, includeRoot))){
            var d = n.global_position.distanceTo(point);
            if(range == -1 || d < range){
                closest = n;
                range = d;
            }
        }
        if(limit_distance>0){
            if(range>limit_distance){
                return  null;
            }
        }
        return closest;
    }
    public static function getClosestEdgeTo(entity:Entity, point:Vect, limit_distance:Float=-1, recurse:Bool=true, includeRoot:Bool=false):Edge{
        var closest:Edge = null;
        var range:Float = -1;
        for(e in (recurse?getEdgesRecursive(entity, false, includeRoot):getEdges(entity, false, includeRoot))){
            if(!e.isPointOnSeg(point)){
                continue;
            }
            var d = e.distanceToPoint(point);
            if(range==-1||d<range){
                closest = e;
                range = d;
            }
        }
        if(limit_distance>0){
            if(range>limit_distance){
                return null;
            }
        }
        return closest;
    }
    public static function getChildByName(entity:Entity, name:String, recursive:Bool=true):Entity{
        for(c in (recursive?getChildrenRecursive(entity, true):entity.children)){
            if(c.name==name){
                return c;
            }
        }
        Util.log.error('No child with name "$name" on $entity.');
        return null;
    }
    public static function isTangible(entity:Entity){
        var type:CoreComponent = entity?.getBaseComponent()?.guid;
        return switch type {
            case NODE: true;
            case EDGE: true;
            case REGION: true;
            case PATH: true;
            default: false;
        }
    }
    public static function asTangible(entity:Entity):Tangible{
        if(!isTangible(entity)){
            Util.log.warn('Tried to get $entity as Tangible; it is not.');
            return null;
        }
        return cast entity;
    }
    public static function isNode(entity:Entity){
        return entity?.getBaseComponent()?.guid==CoreComponent.NODE;
    }
    public static function isEdge(entity:Entity){
        return entity?.getBaseComponent()?.guid==CoreComponent.EDGE;
    }
    public static function isRegion(entity:Entity){
        return entity?.getBaseComponent()?.guid==CoreComponent.REGION;
    }
    public static function hasPosition(entity:Entity){
        return entity?.hasComponentByGUID(CoreComponent.POSITION);
    }
    public static function hasTimelineController(entity:Entity){
        return entity?.hasComponentByGUID(CoreComponent.TIMELINE_CONTROL);
    }
    public static function asPosition(entity:Entity):Position{
        if(entity==null){
            return null;
        }
        if(!hasPosition(entity)){
            Util.log.error('Tried to get ${entity.toString()} as Position. Actual type: ${entity.getBaseComponent()?.guid??"Unknown"}');
        }
        return entity;
    }
    public static function asNode(entity:Entity):Node{
        if(entity==null){
            return null;
        }
        if(!isNode(entity)){
            Util.log.error('Tried to get ${entity.toString()} as Node. Actual type: ${entity.getBaseComponent()?.guid??"Unknown"}');
        }
        return entity;
    }
    public static function asEdge(entity:Entity):Edge{
        if(entity==null){
            return null;
        }
        if(!isEdge(entity)){
            Util.log.error('Tried to get ${entity.toString()} as Edge. Actual type: ${entity.getBaseComponent()?.guid??"Unknown"}');
        }
        return entity;
    }
    public static function asRegion(entity:Entity):Region{
        if(entity==null){
            return null;
        }
        if(!isRegion(entity)){
            Util.log.error('Tried to get ${entity.toString()} as Region. Actual type: ${entity.getBaseComponent()?.guid??"Unknown"}');
        }
        return entity;
    }
    public static function asPath(entity:Entity):Path{
        if(entity==null){
            return null;
        }
        if(!baseIs(entity, PATH)){
            Util.log.error('Tried to get ${entity.toString()} as Path. Actual type: ${entity.getBaseComponent()?.guid??"Unknown"}');
        }
        return entity;
    }
    public static function asTimelineControlled(entity:Entity):TimelineControlled{
        if(entity==null){
            return null;
        }
        if(!entity.hasComponentByGUID(CoreComponent.TIMELINE_CONTROL)){
            trace('Error: Tried to get ${entity.toString()} as TimelineControlled, but it is not.');
        }
        return entity;
    }

    /**
        The index of this entity among its parent's children
    **/
    public static function getChildIndex(entity:Entity):Int{
        if(entity.parent==null){
            return 0; //it is root
        }
        return entity.parent.children.indexOf(entity);
    }
    public static function setIndexOfChild(entity:Entity, child:Entity, index:Int):Int{
        var childIndex = entity.children.indexOf(child);
        if(childIndex==-1){
            Util.log.error('Tried to set index of $child in $entity to $index, but it is not a child of that entity.');
            return -1;
        }
        if(index<0){
            index=0;
        }
        entity.children.remove(child);
        var curlength = entity.children.length;
        if(index>=curlength){
            entity.children.push(child);
            return curlength; 
        }
        entity.children.insert(index, child);
        return index;
    }
    public static function baseIs(entity:Entity, type:CoreComponent):Bool{
        return entity?.getBaseComponent()?.guid==type;
    }
    public static function Nodes(entities:Array<Entity>):Array<Node>{
        return entities.filter(e->isNode(e)).map(e->asNode(e));
    }

    public static function Regions(entities:Array<Entity>):Array<Region>{
        return entities.filter(e->isRegion(e)).map(e->asRegion(e));
    }

    public static function Edges(entities:Array<Entity>, includeIncomplete:Bool=true):Array<Edge>{
        return entities.filter(e->isEdge(e)&&(includeIncomplete||asEdge(e).isComplete)).map(e->asEdge(e));
    }

    public static function Paths(entities:Array<Entity>):Array<Path>{
        return entities.filter(e->baseIs(e, PATH)).map(e->asPath(e));
    }

    public static function getGlobalBoundingRect(entity:Entity):Rect{
        var out = new Rect(0, 0, 0, 0);
        if(isRegion(entity)){
            return asRegion(entity).rect;
        }
        if(isNode(entity)){
            var node = asPosition(entity);
            var nodeglobalpos = node.global_position;
            out.left=out.right=nodeglobalpos.x;
            out.top=out.bottom=nodeglobalpos.y;
        }
        for(n in getNodesRecursive(entity)){
            var gp = n.global_position;
            if(gp.x<out.left){
                out.left = gp.x;
            }
            if(gp.x>out.right){
                out.right = gp.x;
            }
            if(gp.y<out.top){
                out.top = gp.y;
            }
            if(gp.y>out.bottom){
                out.bottom = gp.y;
            }
        }
        return out;
    }
}