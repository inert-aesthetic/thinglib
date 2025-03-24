package thinglib.macro;

import thinglib.Thing;
import thinglib.storage.Reference;
import haxe.macro.Compiler;
import haxe.macro.ExprTools;
import haxe.macro.ComplexTypeTools;
import thinglib.property.core.CoreComponents.CoreComponent;
import thinglib.property.core.CoreComponents.CoreComponentNode;
import haxe.macro.Expr.TypeDefinition;
import haxe.macro.Printer;
import haxe.macro.Expr.TypeDefKind;
import debug.Logger;
import haxe.Log;
import thinglib.Consts;
import thinglib.Util;
import thinglib.component.Entity;
import thinglib.storage.Storage;
import haxe.macro.Expr;
import haxe.macro.Expr.Access;
import haxe.macro.Context;
import haxe.macro.Expr.Field;
import thinglib.property.Component;
import thinglib.ThingScape;
import thinglib.property.PropertyDef;
using Lambda;
using haxe.macro.TypeTools;
using haxe.macro.ComplexTypeTools;

class Codegen{
    static var cglog = new Logger('codegen', VERBOSE);
#if (macro||interp||eval)
    static var root:ThingScape;
    static var storage:Storage;
    static var component_types:Map<ThingID, TypeDefinition> = [];
    static var construct_types:Map<ThingID, TypeDefinition> = [];
    static var property_enum_types:Array<TypeDefinition> = [];
    @:persistent static var component_registry_lookup:Map<String, ThingID> = [];
    @:persistent static var construct_registry_lookup:Map<String, ThingID> = [];
    static var construct_build_order:Array<ThingID> =[];
    
    static final abstractOverEntity = TDAbstract(macro:thinglib.component.Entity, null, null, [macro: thinglib.component.Entity]);

    public static function setupMetadatas(){
        // Compiler.registerCustomMetadata({
        //     metadata: "instancesOf",
        //     doc: "For use on classes extending System. Adds array to `update` that contains all instances of specified prefab.",
        //     params: [
        //         "`prefab:things.Registry.Construct` - The prefab to enumerate.",
        //         "`?name:String` - The name for the array (optional)."
        //     ],
        //     targets: [Class]
        // });
        // Compiler.registerCustomMetadata({
        //     metadata: "entitiesWith",
        //     doc: "For use on classes extending System. Adds array to `update` that contains all instances that have all listed components.",
        //     params: [
        //         "`components:Array<things.Registry.Component>` - The component combination to enumerate.",
        //         "`name:String` - The name for the array."
        //     ],
        //     targets: [Class]
        // });
    }

    public static function generate(path:String){
        Context.onAfterInitMacros(()->{
            if(root==null) root = new ThingScape();
            //Util.log.setPriority(INFO);
            if(storage==null) storage = new Storage(path);

            var construct_names = Util.getAllOfTypeInDirectory(Consts.FILENAME_CONSTRUCT, path);
            var constructs:Array<Entity> = [];
            
            for(c in construct_names){
                var meta:StorageMeta = storage.loadMeta(c);
                if(root.hasThing(meta.guid)){
                    constructs.push(root.unsafeGet(meta.guid));
                    continue;
                }
                constructs.push(storage.createFromFile(Entity, root, c));
            }
            var components = root.getAll(Component);
            try{
                Context.getModule("things.Components");
                cglog.verbose("Components already built.");
            }
            catch(_){
                cglog.info("Build components.");
                for(c in components){
                    var fields:Array<Field> = [];
                    switch c.guid {
                        case EDGE:
                        case NODE:
                        case POSITION:
                        case GROUP:
                        case REGION:
                        case PATH:
                        case TIMELINE_CONTROL:
                        default:
                            var tpath:TypePath = {pack:['things', 'Components'], name:makeTypeName(c.name)};
                            fields.push({
                                name: 'fromEntity',
                                kind: FieldType.FFun({
                                    args: [{name:"entity", type:macro:thinglib.component.Entity}],
                                    expr: macro return cast entity, //TODO: typeguard
                                    ret:null
                                }),
                                meta:[{name:':from', pos:Context.currentPos()}],
                                access:[AStatic],
                                pos:Context.currentPos()
                            });
                            for(d in c.definitions){
                                switch d.type {
                                    default:
                                    case SELECT, MULTI:
                                        generatePropertyEnum(d.options, makeTypeName('${c.name}_${d.name}'));
                                }
                                for(f in generatePropertyAccessorFields(d)){
                                    fields.push(f);
                                }
                            }
                            var def:TypeDefinition = {
                                pos: Context.currentPos(),
                                name:makeTypeName(c.name),
                                pack:[],//['things'],
                                doc:c.guid,
                                kind:abstractOverEntity,
                                fields:fields,
                                meta:[{name:':forward', params: [macro name, macro parent, macro removeChild], pos:Context.currentPos()}]
                            };
                            component_types.set(c.guid, def);
                            cglog.verbose(new Printer().printTypeDefinition(def));
                    }
                }
                Context.defineModule('things.Components', component_types.array().concat(property_enum_types), null, [{
                    pack: ['thinglib','component','util'],
                    name: 'PropertyValueTools'
                }]);
                for(c in construct_names){
                    Context.registerModuleDependency('things.Components', path+c);
                    cglog.info('Register file dep: $path$c');
                }
                for(c in root.getAll(Component)){
                    var isCore:CoreComponent = c.guid;
                    if(isCore==NOT_CORE){
                        Context.registerModuleDependency('things.Components', path+c.name+'.component.json');
                        cglog.info('Register file dep: '+path+c.name+'.component.json');
                    }
                }
                Context.registerModuleDependency('things.Components', 'macro/Codegen.hx');
            }

            try{
                Context.getModule('things.Constructs');
                cglog.verbose("Constructs already build.");
            }
            catch(_){
                cglog.info("Build constructs.");
                for(c in constructs){
                    generateConstructAccessor(c);
                }
    
                for(c in construct_types){
                    cglog.verbose(new Printer().printTypeDefinition(c));
                }
    
                Context.defineModule('things.Constructs', construct_types.array(), 
                    [
                        {
                            pack: ['things'], 
                            name:'Components'
                        },
                        {
                            pack:[],
                            name:'Lambda'
                        }
                    ]
                );

                for(c in construct_names){
                    Context.registerModuleDependency('things.Constructs', path+c);
                    cglog.info('Register file dep: $path$c');
                }
                for(c in root.getAll(Component)){
                    var isCore:CoreComponent = c.guid;
                    if(isCore==NOT_CORE){
                        Context.registerModuleDependency('things.Constructs', path+c.name+'.component.json');
                        cglog.info('Register file dep: '+path+c.name+'.component.json');
                    }
                }
                Context.registerModuleDependency('things.Constructs', 'macro/Codegen.hx');
            }
            try{
                Context.getModule("things.Registry");
                cglog.verbose("Registry already built.");
            }
            catch(_){
                cglog.info("Building registry.");
                var construct_registry_fields:Array<Field> = [];
                for(construct in constructs){
                    var construct_type_name = makeTypeName(construct.name);
                    construct_registry_fields.push({
                        name: construct_type_name,
                        kind: FVar(null, macro $v{construct.guid}),
                        pos: Context.currentPos()
                    });
                
                    construct_registry_lookup.set(construct_type_name, construct.guid);

                }
                
                var construct_registry:TypeDefinition = {
                    pos:Context.currentPos(),
                    pack:[],
                    name:"Construct",
                    kind:TDAbstract(macro:thinglib.Util.ThingID, [AbEnum], [macro:thinglib.Util.ThingID], [macro:thinglib.Util.ThingID]),
                    fields:construct_registry_fields
                }; 
                var component_registry_fields:Array<Field> = [];
                var component_types_keys = [for(k in component_types.keys()) k].concat(CoreComponent.createAll());
                for(id in component_types_keys){
                    component_registry_fields.push({
                        name: makeTypeName(root.unsafeGet(id).name+"Component"),
                        kind: FVar(null, macro $v{id}),
                        pos: Context.currentPos()
                    });
                    component_registry_lookup.set(makeTypeName(root.unsafeGet(id).name+"Component"), id);
                }
                var component_registry:TypeDefinition = {
                    pos:Context.currentPos(),
                    pack:[],
                    name:"Component",
                    kind:TDAbstract(macro:thinglib.Util.ThingID, [AbEnum], [macro:thinglib.Util.ThingID], [macro:thinglib.Util.ThingID]),
                    fields:component_registry_fields
                }; 
                for(id in [NODE, POSITION, PATH, REGION, EDGE, TIMELINE_CONTROL]){
                    component_registry.fields.push({
                        {
                            name: makeTypeName(root.unsafeGet(id).name),
                            kind: FVar(null, macro $v{id}),
                            pos: Context.currentPos()
                        }
                    });
                }
                
                cglog.verbose(new Printer().printTypeDefinition(component_registry));
                cglog.verbose(new Printer().printTypeDefinition(construct_registry));
    
                Context.defineModule('things.Registry', [component_registry, construct_registry]);
                for(c in construct_names){
                    Context.registerModuleDependency('things.Registry', path+c);
                    cglog.info('Register file dep: $path$c');
                }
                for(c in root.getAll(Component)){
                    var isCore:CoreComponent = c.guid;
                    if(isCore==NOT_CORE){
                        Context.registerModuleDependency('things.Registry', path+c.name+'.component.json');
                        cglog.info('Register file dep: '+path+c.name+'.component.json');
                    }
                }
                Context.registerModuleDependency('things.Registry', 'macro/Codegen.hx');
            }
        });
        //cglog.log("\n"+component_types.map(c->'${c.name}:${c.doc}').join("\n"));
    }

// #region generator functions    
    static function generatePropertyEnum(values:Array<String>, name:String){
        var ret:TypeDefinition = {
            pos: Context.currentPos(),
            pack: [],
            name: '${makeTypeName(name)}_values',
            fields: [
                for(v in values){
                    {
                        name: v.toUpperCase().split(" ").join("_"),
                        kind: FVar(null),
                        pos: Context.currentPos()
                    }
                }
            ],
            kind: TDAbstract(macro:Int, [AbEnum], [macro:Int], [macro:Int])
        };
        cglog.verbose(new Printer().printTypeDefinition(ret));
        property_enum_types.push(ret);

        // );
    }

    static function generateComponentGetter(component:Component){
        var fields:Array<Field> = [];
        switch component.guid {
            case EDGE:
                fields.push({
                    pos:Context.currentPos(),
                    name:"edge",
                    kind:FProp('get', 'never', macro:thinglib.component.Accessors.Edge),
                    access:[APublic]
                });
                fields.push({
                    pos:Context.currentPos(),
                    name:'get_edge',
                    kind:FFun({
                        args: [],
                        expr: macro return this,
                        ret:null
                    })
                });
            case TIMELINE_CONTROL:
                fields.push({
                    pos:Context.currentPos(),
                    name:"timeline_control",
                    kind:FProp('get', 'never', macro:thinglib.component.Accessors.TimelineControlled),
                    access:[APublic]
                });
                fields.push({
                    pos:Context.currentPos(),
                    name:'get_timeline_control',
                    kind:FFun({
                        args: [],
                        expr: macro return this,
                        ret:null
                    })
                });
            case NODE:
                fields.push({
                    pos:Context.currentPos(),
                    name:"node",
                    kind:FProp('get', 'never', macro:thinglib.component.Accessors.Node),
                    access:[APublic]
                });
                fields.push({
                    pos:Context.currentPos(),
                    name:'get_node',
                    kind:FFun({
                        args: [],
                        expr: macro return this,
                        ret:null
                    })
                });
            case POSITION:
                fields.push({
                    pos:Context.currentPos(),
                    name:"position",
                    kind:FProp('get', 'never', macro:thinglib.component.Accessors.Position),
                    access:[APublic]
                });
                fields.push({
                    pos:Context.currentPos(),
                    name:'get_position',
                    kind:FFun({
                        args: [],
                        expr: macro return this,
                        ret:null
                    })
                });
            case PATH:
                fields.push({
                    pos:Context.currentPos(),
                    name:"path",
                    kind:FProp('get', 'never', macro:thinglib.component.Accessors.Path),
                    access:[APublic]
                });
                fields.push({
                    pos:Context.currentPos(),
                    name:'get_path',
                    kind:FFun({
                        args: [],
                        expr: macro return this,
                        ret:null
                    })
                });
            case REGION:
                fields.push({
                    pos:Context.currentPos(),
                    name:"region",
                    kind:FProp('get', 'never', macro:thinglib.component.Accessors.Region),
                    access:[APublic]
                });
                fields.push({
                    pos:Context.currentPos(),
                    name:'get_region',
                    kind:FFun({
                        args: [],
                        expr: macro return this,
                        ret:null
                    })
                });
            case GROUP:
            default:
                // if(!component_types.exists(component.guid)){
                //     trace("Missing def!");
                //     continue;
                // }
                for(f in generateComponentAccessorFields(component)){
                    fields.push(f);
                }
        }
        return fields;
    }

    static function generateConstructAccessor(construct:Entity, ?mangle_name:String=""):TypeDefinition{
        var c:Entity = construct;
        if(construct_types.exists(c.guid)){
            return construct_types.get(c.guid);
        }
        for(dep in c.dependencies){
            if(dep.type==ENTITY&&!construct_types.exists(dep.guid)){
                generateConstructAccessor(root.resolveDependency(root, dep, storage));
            }
        }
        var fields:Array<Field> = [];
        var tpath:TypePath = {pack:['things', 'Components'], name:makeTypeName(c.name)};
        fields.push({
            name: 'fromEntity',
            kind: FieldType.FFun({
                args: [{name:"entity", type:macro:thinglib.component.Entity}],
                expr: macro return cast entity, //TODO: typeguard
                ret:null
            }),
            meta:[
                {name:':from', pos:Context.currentPos()}
            ],
            access:[AStatic],
            pos:Context.currentPos()
        });
        for(component in c.components){
            for(f in generateComponentGetter(component)){
                fields.push(f);
            };
        }

        var children_type:ComplexType;
        // Handle typing of children array
        if(c.children_base_entity!=null){
            var cdef = construct_types.get(c.children_base_entity.guid);
            children_type = TPath({pos:Context.currentPos(), pack:['things'], name:'Constructs', sub:cdef.name});
        }
        else if(c.children_base_component!=null){
            var cdef = component_types.get(c.children_base_component.guid);
            children_type = TPath({pos:Context.currentPos(), pack:['things'], name:'Components', sub:cdef.name});
        }
        else{
            children_type = Context.getType('thinglib.component.Entity').toComplexType();
            for(child in c.children){
                var child_def = generateConstructAccessor(child, makePropName(c.name));
                var ca:TypePath = {pack: [], params: [TPType(children_type)], name: 'Array'}
                var cat:ComplexType = TPath(ca);
                var child_type:ComplexType = TPath({pos:Context.currentPos(), pack:['things'], name:'Constructs', sub:child_def.name});//haxe.macro.TypeTools.toComplexType(Context.getType('things.Constructs.${child_def.name}'));
                fields.push({
                    pos:Context.currentPos(),
                    name:makePropName(child.name),
                    //doc:component.guid,
                    kind:FProp('get', 'never', child_type),
                    access:[APublic]
                });
                fields.push({
                    pos:Context.currentPos(),
                    name:'get_'+makePropName(child.name),
                    kind:FFun({
                        args: [],
                        expr: macro return this.children.find(ct->ct.guid==$v{child.guid}),
                        ret:null
                    })
                });
            }
        }
        var ca:TypePath = {pos:Context.currentPos(), pack: [], params: [TPType(children_type)], name: 'Array'}
        var cat:ComplexType = TPath(ca);
        fields.push({
            pos:Context.currentPos(),
            name:'children',
            //doc:component.guid,
            kind:FProp('get', 'never', cat),
            access:[APublic]
        });
        fields.push({
            pos:Context.currentPos(),
            name:'get_children',
            kind:FFun({
                args: [],
                expr: macro return cast this.children,
                ret:null
            })
        });
        fields.push({
            pos:Context.currentPos(),
            name:'addChild',
            kind:FFun({
                args:[{name:'child', type:children_type}],
                expr: macro this.addChild(child),
                ret:null
            })
        });

        var def:TypeDefinition = {
            pos: Context.currentPos(),
            name:makeTypeName(c.name, "instance"+(mangle_name==""?"":'_$mangle_name')),
            pack:[],
            doc:c.guid,
            kind:abstractOverEntity,
            fields:fields,
            meta:[
                {name:':forward', params: [macro name, macro parent, macro removeChild], pos:Context.currentPos()}
            ],
        }
        
        construct_types.set(c.guid, def);
        return def;
    }

    static function generatePropertyAccessorFields(definition:PropertyDef):Array<Field>{

        var fields:Array<Field> = [];
        var constraint = macro:thinglib.component.Entity;
        if(definition.ref_base_type_guid!=Reference.EMPTY_ID){
            var basetype:Thing = definition.reference.getRoot().unsafeGet(definition.ref_base_type_guid);
            if(basetype==null){
                cglog.warn('Unable to find constraint ${definition.ref_base_type_guid} for $definition.');
            }
            else{
                if(basetype.thingType==ENTITY){
                    constraint = TPath({
                        pack: ['things'],
                        name: 'Constructs',
                        sub: makeTypeName(basetype.name)+"_instance"
                    });
                }
                else if(basetype.thingType==COMPONENT){
                    constraint = TPath({
                        pack: ['things'],
                        name: 'Components',
                        sub: makeTypeName(basetype.name)
                    });
                }
                else{
                    cglog.warn('$basetype is not a valid constraint for $definition.');
                }
            }
        }
        fields.push({
            pos:Context.currentPos(),
            doc:definition.documentation,
            kind:FProp('get', 'set', 
                switch definition.type {
                    case INT: macro:Int;
                    case FLOAT: macro:Float;
                    case STRING: macro:String;
                    case BOOL: macro:Bool;
                    case COLOR: macro:Int;
                    case SELECT: TPath({
                        pack: ['things'],
                        name: 'Components',
                        sub: makeTypeName('${definition.component.name}_${definition.name}')+"_values"
                    });
                    case MULTI: TPath({pack: [], params: [TPType(TPath({
                        pack: ['things'],
                        name: 'Components',
                        sub: makeTypeName('${definition.component.name}_${definition.name}')+"_values"
                    }))], name: 'Array'});
                    case REF: constraint;
                    case REFS: TPath({pack: [], params: [TPType(constraint)], name: 'Array'});//TODO?
                    case URI: macro:String; //TODO
                    case BLANK: macro:Null<Any>;
                    case UNKNOWN: macro:Null<Any>;
                }
            ),
            access:[APublic],
            name:makePropName(definition.name),
        });
        fields.push({
            name: 'get_' + makePropName(definition.name),
            kind: FieldType.FFun({ 
                args: [], 
                expr: switch definition.type {
                    case INT: macro return this.getValueByGUID($v{definition.guid}).intValue();
                    case FLOAT: macro return this.getValueByGUID($v{definition.guid}).floatValue();
                    case STRING: macro return this.getValueByGUID($v{definition.guid}).stringValue();
                    case BOOL: macro return this.getValueByGUID($v{definition.guid}).boolValue();
                    case COLOR: macro return this.getValueByGUID($v{definition.guid}).intValue();
                    case SELECT: macro return this.getValueByGUID($v{definition.guid}).intValue();
                    case MULTI: macro return this.getValueByGUID($v{definition.guid}).intArrayValue();
                    case REF: macro return this.getValueByGUID($v{definition.guid}).entityValue(this);
                    case REFS: macro return this.getValueByGUID($v{definition.guid}).entityArrayValue(this);
                    case URI: macro return this.getValueByGUID($v{definition.guid}).stringValue(); //todo
                    case BLANK: macro return null;
                    case UNKNOWN: macro return null;
                }, 
                ret: null 
            }),
            pos: Context.currentPos()
        });
        fields.push({
            name: 'set_' + makePropName(definition.name),
            kind: FieldType.FFun({ 
                args: [{ name:'value', type:null } ], 
                expr: switch definition.type {
                    case INT: macro $b{[macro this.setValueByGUID($v{definition.guid}, INT(value)), macro return value]};
                    case FLOAT: macro $b{[macro this.setValueByGUID($v{definition.guid}, FLOAT(value)), macro return value]};
                    case STRING: macro $b{[macro this.setValueByGUID($v{definition.guid}, STRING(value)), macro return value]};
                    case BOOL: macro $b{[macro this.setValueByGUID($v{definition.guid}, BOOL(value)), macro return value]};
                    case COLOR: macro $b{[macro this.setValueByGUID($v{definition.guid}, COLOR(value)), macro return value]};
                    case SELECT: macro $b{[macro this.setValueByGUID($v{definition.guid}, SELECT(value)), macro return value]};//todo
                    case MULTI: macro $b{[macro this.setValueByGUID($v{definition.guid}, MULTI(value)), macro return value]}; //todo
                    case REF: macro $b{[macro this.setValueByGUID($v{definition.guid}, REF(cast(value,thinglib.component.Entity).guid)), macro return value]};
                    case REFS: macro $b{[macro this.setValueByGUID($v{definition.guid}, REFS(value.map(v->v.guid))), macro return value]};
                    case URI: macro $b{[macro this.setValueByGUID($v{definition.guid}, URI(value)), macro return value]}; //todo
                    case BLANK: macro return null;
                    case UNKNOWN: macro return null;
                }, 
                ret: null
            }),
            pos: Context.currentPos()
        });
        return fields;
    }

    static function generateComponentAccessorFields(component:Component):Array<Field>{
        var fields:Array<Field> = [];
        //var cdef = component_types.get(component.guid);
        var ctype = haxe.macro.TypeTools.toComplexType(Context.getType('things.Components.${makeTypeName(component.name)}'));
        fields.push({
            pos:Context.currentPos(),
            name:makePropName(component.name),
            //doc:component.guid,
            kind:FProp('get', 'never', ctype),
            access:[APublic]
        });
        fields.push({
            pos:Context.currentPos(),
            name:'get_'+makePropName(component.name),
            kind:FFun({
                args: [],
                expr: macro return this,
                ret:null
            })
        });
        return fields;
    }
// #endregion

// #if (macro||display||eval)
// #region System builder
    public static function buildSystem(){
        var fields = Context.getBuildFields();
        var lc = Context.getLocalClass();

        var target = fields.find(f->f?.name=="update");
        if(target==null) return fields;
        trace("Try build");

        var new_exprs:Array<Expr> = [];
        var docs:Array<String> = [];
        var metas = lc.get().meta.get();
        // trace(metas);
        for(m in metas){
            switch(m.name){
                default:
                case ":component", "component":
                    if(m.params?.length>=1){
                        var fieldname=null;
                        if(m.params.length==2) fieldname = ExprTools.getValue(m.params[1]);

                        switch m.params[0].expr {
                            default:
                            case EConst(c): 
                                switch c {
                                    default:
                                    case CIdent(s):
                                        var id = component_registry_lookup.get(s);
                                        if(id==null){
                                            cglog.error('No component in registry with name: $id.');
                                        }
                                        var corecomp:CoreComponent=id;
                                        cglog.info("ID: "+id);
                                        fieldname??=makePropName(s+"_list");
                                        var obj:Entity=root.unsafeGet(id);
                                        var tpath:ComplexType =  TPath(switch corecomp {
                                            case POSITION:
                                                {
                                                    pack: ['thinglib', 'component'], 
                                                    pos: Context.currentPos(),
                                                    name: 'Accessors',
                                                    sub: 'Position'
                                                }
                                            case NODE:
                                                {
                                                    pack: ['thinglib', 'component'], 
                                                    pos: Context.currentPos(),
                                                    name: 'Accessors',
                                                    sub: 'Node'
                                                }
                                            case EDGE:
                                                {
                                                    pack: ['thinglib', 'component'], 
                                                    pos: Context.currentPos(),
                                                    name: 'Accessors',
                                                    sub: 'Edge'
                                                }
                                            case GROUP:
                                                {
                                                    pack: ['thinglib', 'component'], 
                                                    pos: Context.currentPos(),
                                                    name: 'Accessors',
                                                    sub: 'Group'
                                                }
                                            case REGION:
                                                {
                                                    pack: ['thinglib', 'component'], 
                                                    pos: Context.currentPos(),
                                                    name: 'Accessors',
                                                    sub: 'Region'
                                                }
                                            case PATH:
                                                {
                                                    pack: ['thinglib', 'component'], 
                                                    pos: Context.currentPos(),
                                                    name: 'Accessors',
                                                    sub: 'Path'
                                                }
                                            case TIMELINE_CONTROL:
                                                {
                                                    pack: ['thinglib', 'component'], 
                                                    pos: Context.currentPos(),
                                                    name: 'Accessors',
                                                    sub: 'TimelineControlled'
                                                }
                                            case NOT_CORE:
                                                    {
                                                        pack: ['things'], 
                                                        pos: Context.currentPos(),
                                                        name: 'Components',
                                                        sub: makeTypeName(obj.name)
                                                    };
                                        });
                                        var ctype:ComplexType = TPath({pack: [], pos:Context.currentPos(), params: [TPType(tpath)], name: "Array"}); 
                                        new_exprs.push({
                                            expr: EVars([{name: fieldname, type:ctype, expr: macro cast root.getAll(thinglib.component.Entity).filter(f->f.hasComponentByGUID($v{id}))}]),
                                            pos: Context.currentPos(),
                                        });  
                                        docs.push('`$fieldname` - Array of all ${obj.name} components.');
                                }
                        }
                    }
                case ":entitiesWith", "entitiesWith":
                    var comps:Array<{name:String, id:ThingID}> = [];
                    if(m.params?.length==2){
                        var fieldname = ExprTools.getValue(m.params[1]);
                        switch m.params[0].expr{
                            default:
                            case EArrayDecl(values):
                                for(v in values){
                                    switch (v.expr){
                                        default:
                                        case EConst(c):
                                            switch(c){
                                                default:
                                                case CIdent(s):
                                                    if(component_registry_lookup.exists(s)){
                                                        comps.push({name:s, id:component_registry_lookup.get(s)});
                                                    }
                                            }
                                        
                                    }
                                }

                        }
                        var lfields:Array<Field> = [];
                        lfields.push({
                            name: 'fromEntity',
                            kind: FieldType.FFun({
                                args: [{name:"entity", type:macro:thinglib.component.Entity}],
                                expr: macro return cast entity, //TODO: typeguard
                                ret:null
                            }),
                            meta:[
                                {name:':from', pos:Context.currentPos()},
                                // {name:':forward', params: [macro parent], pos:Context.currentPos()}
                            ],
                            access:[AStatic],
                            pos:Context.currentPos()
                        });
                        for(component in comps){
                            for(f in generateComponentGetter(root.unsafeGet(component.id))){
                                lfields.push(f);
                            };
                        }
                        var localtype:TypeDefinition = {
                            pos:Context.currentPos(),
                            pack:[],
                            name:makeTypeName(fieldname, 'accessor'),
                            kind:abstractOverEntity,
                            fields:lfields
                        };
                        cglog.info(new Printer().printTypeDefinition(localtype));
                        Context.defineType(localtype, Context.getLocalModule());
                        var ctype = Context.getType(makeTypeName(fieldname, 'accessor')).toComplexType();
                        var atype:ComplexType = TPath({pack:[], pos:Context.currentPos(), params:[TPType(ctype)], name:"Array"});
                        // var ctype:ComplexType = TPath({pack: [], pos:Context.currentPos(), params: [TinstancesOfPType(TPath(
                        //     {
                        //         pack: ['things'], 
                        //         pos: Context.currentPos(),
                        //         name: 'Constructs',
                        //         sub: makeTypeName(obj.name, 'instance')
                        //     }))], name: "Array"}); 
                        var cids = [for(c in comps){c.id;}];
                        new_exprs.push({
                            expr: EVars([{name: makePropName(fieldname+'_list'), type:atype, 
                                expr: macro cast root.getAll(thinglib.component.Entity).filter(f->{
                                    for(c in $v{cids}){
                                        if(!f.hasComponentByGUID(c)){
                                            return false;
                                        }
                                    }
                                    return true;
                                })}]),
                            pos: Context.currentPos(),
                        });  
                        docs.push('`${makePropName(fieldname+'_list')}` - Array of all entities with components: ${[for(c in comps){c.name;}].join(", ")}.');
                    }
                case ":instancesOf", "instancesOf":
                    if(m.params?.length>=1){
                        var fieldname:String = null;
                        if(m.params[1]!=null){
                            fieldname = ExprTools.getValue(m.params[1]);
                            
                        }
                        switch m.params[0].expr {
                            default:
                            case EConst(c): 
                                switch c {
                                    default:
                                    case CIdent(s):
                                        var id = construct_registry_lookup.get(s);
                                        if(id==null){
                                            cglog.error('No construct in registry with name: $id.');
                                        }
                                        cglog.info("ID: "+id);
                                        fieldname??=makePropName(s)+"_instances";
                                        var obj:Entity=root.unsafeGet(id);
                                        var ctype:ComplexType = TPath({pack: [], pos:Context.currentPos(), params: [TPType(TPath(
                                            {
                                                pack: ['things'], 
                                                pos: Context.currentPos(),
                                                name: 'Constructs',
                                                sub: makeTypeName(obj.name, 'instance')
                                            }))], name: "Array"}); 
                                        new_exprs.push({
                                            expr: EVars([{name: fieldname, type:ctype, expr: macro cast root.getAll(thinglib.component.Entity).filter(f->f.instanceOf?.guid==$v{id})}]),
                                            pos: Context.currentPos(),
                                        });  
                                        docs.push('`$fieldname` - Array of all instances of `$s` prefab.');
                                }
                        }
                    }

            }
        }

        var target_func:Function = switch target.kind {
            case FFun(f): f;
            default: null;
        }
        target_func.expr = macro $b{target_func.expr==null?new_exprs:new_exprs.concat(target_func.expr.expr.getParameters()[0])};
        target.doc = docs.join("\n\n");
        cglog.log(new Printer().printExpr(target_func.expr));

        return fields;
    }
    #end
// #endregion

// #region name format helper functions
    static function makeTypeName(v:String, ?suffix:String=""){
        return v.split(" ").map(s->s.charAt(0).toUpperCase()+s.substr(1)).join("")+(suffix==""?"":'_${suffix}');
    }

    static function makePropName(v:String){
        return (v.charAt(0).toLowerCase()+v.substr(1)).split(" ").join("_");
    }
// #endregion


}