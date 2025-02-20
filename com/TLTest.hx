package;

import thinglib.property.core.CoreComponents.CoreComponentPosition;
import thinglib.property.core.CoreComponents.CoreComponentNode;
import thinglib.timeline.Timeline;
import thinglib.property.core.CoreComponents.CoreComponent;
import thinglib.storage.Storage;
import thinglib.storage.Reference;
import thinglib.property.Component;
import thinglib.ThingScape;
import haxe.Json;
import utest.Assert;
import buddy.SingleSuite;
import thinglib.property.PropertyDef;
import thinglib.Consts;
import thinglib.Util;
import thinglib.component.Entity;
using buddy.Should;
using hx.strings.Strings;
using Lambda;
using thinglib.component.util.EntityTools;
using thinglib.component.util.PropertyValueTools;

@colorize
class TLTest extends SingleSuite{
    public function new(){
        Util.log.setThrowPriority(NONE);
        describe("Building, saving, reloading, resaving constructs", {
            var storage = new Storage("./test_project/");
            var root = new ThingScape();
            var propdeflist = new Component(root, "tests");
            PropertyType.createAll().iter(t->{
                propdeflist.definitions.push(new PropertyDef(propdeflist, '${t}_test', t));
            });
            storage.save(propdeflist.filename, propdeflist);
            var construct = new Entity(root, "test");
            for(i in 0...5){
                var e = new Entity(construct);
                //e.addProperty(root.getThing(PROPERTYDEF, PropertyDef.BASE_NODE), VECT({x:10*i, y:20*i}));
                e.addComponent(root.getThing(COMPONENT, CoreComponent.NODE));
                var en = e.asNode();
                en.x = 10*i;
                en.y = 20*i;
                construct.addChild(e);
            }
            var p = construct.children[0];
            p.addComponent(root.getThing(COMPONENT, CoreComponent.GROUP));
            it("should not allow two base-type properties to exist on one entity.", {
                p.hasComponentByGUID(CoreComponent.GROUP).should.not.be(true);
            });
            it("should have a base when you add one.", {
                p.hasComponentByGUID(CoreComponent.NODE).should.be(true);
            });
            construct.addChild(construct.children[0]);
            it("should prevent the same child from being added multiple times.", {
                construct.children.filter(c->c.isEqualTo(construct.children[0])).length.should.be(1);
            });
            var p = construct.children[1];
            p.addComponent(propdeflist);
            for(prop in propdeflist.definitions){
                p.setValue(prop, switch prop.type {
                    case INT: INT(5);
                    case FLOAT: FLOAT(3.5);
                    case STRING: STRING("test");
                    case BOOL: BOOL(true);
                    case COLOR: COLOR(0xFF0000);
                    case SELECT: SELECT(7);
                    case MULTI: MULTI([1, 3, 5]);
                    case REF: REF(construct.children[0].guid);
                    case REFS: REFS([construct.children[1].guid, construct.children[2].guid]);
                    case URI: URI("../res/dummy.png");
                    //case VECT: VECT(new Vect(3.14, 42));
                    //case VECTS: VECTS([new Vect(1, 2.3), new Vect(59999, 123.456789)]);
                    //case RECT: RECT(new Vect(1, 2), 3, 4);
                    case BLANK: BLANK;
                    case UNKNOWN: NONE;
                });
            }
            var group = new Entity(root, "group_test");
            group.addComponent(root.getThing(COMPONENT, CoreComponent.GROUP));
            group.children_base_component=construct.children[2].getBaseComponent();
            group.addChild(construct.children[2]);
            construct.addChild(group);
            
            var markerpropslist = new Component(root, "marker_props");
            var coinsdef = new PropertyDef(markerpropslist, "coins", INT);
            var notedef = new PropertyDef(markerpropslist, "note", STRING);
            markerpropslist.definitions.push(coinsdef);
            markerpropslist.definitions.push(notedef);
            storage.save(markerpropslist.filename, markerpropslist);
            
            var nested_marker = new Entity(root, "nested_marker");
            nested_marker.addComponent(markerpropslist);
            nested_marker.addComponent(root.getThing(COMPONENT, CoreComponent.NODE));
            nested_marker.asNode().x = 5;
            nested_marker.setValue(notedef, STRING("Hiding in here"));
            
            
            nested_marker.addComponent(root.unsafeGet(CoreComponent.TIMELINE_CONTROL));
            var timeline=Timeline.Create(nested_marker);
            var state=timeline.getState("Default");
            var track = state.addTrack(CoreComponentPosition.x_def);
            track.addKeyframe(10, FLOAT(15), LINEAR);
            track.addKeyframe(20, FLOAT(25), LINEAR);
            
            nested_marker.timeline=timeline;

            storage.save(nested_marker.filename, nested_marker);
            
            var shared_entity = new Entity(root, "marker");
            shared_entity.addComponent(markerpropslist);
            shared_entity.addComponent(root.getThing(COMPONENT, CoreComponent.NODE));
            shared_entity.setValue(coinsdef, INT(5));
            shared_entity.setValue(notedef, STRING("Default Note"));
            var nested_instance_child = Entity.CreateInstance(root, nested_marker, null, "mega_complication");
            nested_instance_child.setValue(notedef, STRING("Unremembered override"));
            var instanced_child = new Entity(root, "marker_child");
            shared_entity.addChild(instanced_child);
            instanced_child.addChild(new Entity(root, "child1"));
            shared_entity.addChild(nested_instance_child);
            instanced_child.addChild(new Entity(root, "child2"));
            storage.save(shared_entity.filename, shared_entity);
            
            var instancechild = Entity.CreateInstance(root, shared_entity);
            construct.addChild(instancechild);
            instancechild.setValue(notedef, STRING("Custom Note"));
            //instancechild.addProperty(root.getThing(PROPERTYDEF, PropertyDef.BASE_INSTANCE), REF(shared_entity.guid));
            var instancechildname = instancechild.name;

            var nestedinstanceoverride = "No, I found YOU!";
            instancechild.children.find(c->c.name=="mega_complication").setValue(notedef, STRING(nestedinstanceoverride));
            
            var instancenestedchild = instancechild.getChildByName("marker_child");
            instancenestedchild.addChildAt(new Entity(instancenestedchild, "added1"), 2);
            instancenestedchild.addChildAt(new Entity(instancenestedchild, "added2"), 3);
            
            var nested_marker_instance = Entity.CreateInstance(root, nested_marker);
            nested_marker_instance.setValue(notedef, STRING("Found you"));
            instancenestedchild.addChild(nested_marker_instance);
            nested_marker_instance.addChild(new Entity(nested_marker_instance, "complication")); //we're barking up wrong tree
            
            instancenestedchild.getChildByName("added1").addChild(new Entity(root, "not_an_instance"));
            
            storage.save(construct.filename, construct);
            
            Util.log.verbose(construct.dependencies);
            Util.log.verbose(shared_entity.dependencies);

            root = new ThingScape(); //reset the world
                    
            var construct_2 = new Entity();
            storage.loadFromFile(root, construct_2, Util.fileName("test", Consts.FILENAME_CONSTRUCT));
            construct_2.name = "test2";

            it("should have matching properties on instances even though they weren't serialized.", {
                var obj = construct_2.children.find(c->c.name==instancechildname);
                var val = obj.getValueByName("coins");
                val.intValue().should.be(5);
            });
            it("should load overridden values for instances when they exist.", {
                var obj = construct_2.children.find(c->c.name==instancechildname);
                var val = obj.getValueByName("note");
                val.stringValue().should.be("Custom Note");
            });
            it("should have re-added the children added to instances when rehydrating.", {
                var instance = construct_2.children.find(c->c.name==instancechildname);
                var nested = instance.getChildByName("marker_child");
                var c1 = nested.getChildAt(2);
                var c2 = nested.getChildAt(3);
                c1.should.not.be(null);
                c2.should.not.be(null);
                c1.name.should.be("added1");
                c2.name.should.be("added2");
                c1.getChildByName("not_an_instance").should.not.be(null);
                nested.children.length.should.be(5);
            });
            it("should correctly target overrides on nested instance", {
                var instance = construct_2.children.find(c->c.name==instancechildname);
                var nested = instance.getChildByName("mega_complication");
                nested.getValueByName("note").stringValue().should.be(nestedinstanceoverride);
            });
            it("should interpolate values based on timeline keyframes", {
                var instance = construct_2.children.find(c->c.name==instancechildname);
                var nested = instance.getChildByName("mega_complication");
                var ntc = nested.asTimelineControlled();
                ntc.frame = 5;
                nested.asNode().x.should.be(10);
                ntc.frame = 15;
                nested.asNode().x.should.be(20);
            });

            storage.save(construct_2.filename, construct_2);
            var c1 = construct.serialize();
            construct_2.name = "test";
            var c2 = construct_2.serialize();
            it("should result in two identical contructs.", {
               Assert.same(c1, c2, "Constructs don't match.\n"+Json.stringify(c1, null, '\t').diff(Json.stringify(c2, null, '\t'))); 
            });

            var propdefs = root.getAll(PropertyDef);
            it("should only contain PROPDEFs in this array.", 
            {
                propdefs.length.should.not.be(0);
                propdefs.iter(propdef->propdef.thingType.should.be(ReferenceType.PROPERTYDEF));
            });

        });
    }
}