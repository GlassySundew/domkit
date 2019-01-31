package domkit;

enum SetAttributeResult {
	Ok;
	Unknown;
	Unsupported;
	InvalidValue( ?msg : String );
}

class Element<T> {

	public var id : String;
	public var obj : T;
	public var component : Component<T,Dynamic>;
	public var classes : Array<String>;
	public var parent : Element<T>;
	public var children : Array<Element<T>> = [];
	var style : Array<{ p : Property, value : Any }> = [];
	var currentSet : Array<Property> = [];
	var needStyleRefresh : Bool = true;

	public function new(obj,component,?parent) {
		this.obj = obj;
		this.component = component;
		this.parent = parent;
		if( parent != null ) parent.children.push(this);
	}

	public function remove() {
		if( parent != null ) {
			parent.children.remove(this);
			parent = null;
		}
		removeElement(this);
	}

	function initStyle( p : String, value : Dynamic ) {
		style.push({ p : Property.get(p), value : value });
	}

	public function initAttributes( attr : haxe.DynamicAccess<String> ) {
		var parser = new CssParser();
		for( a in attr.keys() ) {
			var ret;
			var p = Property.get(a,false);
			if( p == null )
				ret = Unknown;
			else {
				var h = component.getHandler(p);
				if( h == null && p != pclass && p != pid )
					ret = Unsupported;
				else
					ret = setAttribute(a, parser.parseValue(attr.get(a)));
			}
			#if sys
			if( ret != Ok )
				Sys.println(component.name+"."+a+"> "+ret);
			#end
		}
	}

	public function setAttribute( p : String, value : CssValue ) : SetAttributeResult {
		var p = Property.get(p,false);
		if( p == null )
			return Unknown;
		if( p.id == pid.id ) {
			switch( value ) {
			case VIdent(i):
				if( id != i ) {
					id = i;
					needStyleRefresh = true;
				}
			default: return InvalidValue();
			}
			return Ok;
		}
		if( p.id == pclass.id ) {
			switch( value ) {
			case VIdent(i): classes = [i];
			case VGroup(vl): classes = [for( v in vl ) switch( v ) { case VIdent(i): i; default: return InvalidValue(); }];
			default: return InvalidValue();
			}
			needStyleRefresh = true;
			return Ok;
		}
		var handler = component.getHandler(p);
		if( handler == null )
			return Unsupported;
		var v : Dynamic;
		try {
			v = handler.parser(value);
		} catch( e : Property.InvalidProperty ) {
			return InvalidValue(e.message);
		}
		var found = false;
		for( s in style )
			if( s.p == p ) {
				s.value = v;
				style.remove(s);
				style.push(s);
				found = true;
				break;
			}
		if( !found ) {
			style.push({ p : p , value : v });
			for( s in currentSet )
				if( s == p ) {
					found = true;
					break;
				}
			if( !found ) currentSet.push(p);
		}
		handler.apply(obj,v);
		return Ok;
	}

	public static dynamic function addElement( e : Element<Dynamic>, to : Element<Dynamic> ) {
		throw "Custom Element.addElement not implemented";
	}

	public static dynamic function removeElement( e : Element<Dynamic> ) {
		throw "Custom Element.removeElement not implemented";
	}

	static var pclass = Property.get("class");
	static var pid = Property.get("id");
	public static function create<BaseT,T:BaseT>( comp : String, attributes : haxe.DynamicAccess<String>, ?parent : Element<BaseT>, ?value : T ) {
		var c = Component.get(comp);
		if( c == null ) throw "Unknown component "+comp;
		var e = new Element<BaseT>(value == null ? c.make(parent == null ? null : parent.obj) : value, cast c, parent);
		if( attributes != null ) e.initAttributes(attributes);
		if( parent != null && value != null ) addElement(e, parent);
		return e;
	}

}