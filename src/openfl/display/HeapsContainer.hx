package openfl.display;

#if flash
import openfl._internal.renderer.flash.FlashRenderer;
import openfl._internal.renderer.flash.FlashHeaps;
import openfl.display3D.Program3D;
import openfl.display3D.Context3D;
import openfl.display3D.VertexBuffer3D;
import openfl.display3D.IndexBuffer3D;
import openfl.display3D.Context3DProgramType;
import openfl.geom.Matrix3D;
import openfl.utils.AGALMiniAssembler;
#else
import openfl._internal.renderer.context3D.Context3DHeaps;
#end
import openfl.display3D.textures.TextureBase;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.events.RenderEvent;
import openfl.geom.Point;
import openfl.Lib;
#if (heaps && !macro)
import h3d.Engine;
import h3d.mat.Data;
import h3d.mat.DepthBuffer;
import h3d.mat.Texture;
import hxd.System;
import hxd.Window;
import hxd.Event;

@:access(openfl.display3D.Context3D)
@:access(hxd.Window)
@:access(h3d.Engine)
@:access(h3d.impl.GlDriver)
@:access(h3d.impl.Stage3dDriver)
class HeapsContainer extends #if !flash DisplayObject #else Bitmap implements IDisplayObject #end
{
	public static var heapsRenderTargets:Array<Texture> = [];

	#if !flash
	/**
		Controls whether or not the Bitmap object is snapped to the nearest pixel.
		This value is ignored in the native and HTML5 targets.
		The PixelSnapping class includes possible values:

		* `PixelSnapping.NEVER` - No pixel snapping occurs.
		* `PixelSnapping.ALWAYS` - The image is always snapped to
		the nearest pixel, independent of transformation.
		* `PixelSnapping.AUTO` - The image is snapped to the
		nearest pixel if it is drawn with no rotation or skew and it is drawn at a
		scale factor of 99.9% to 100.1%. If these conditions are satisfied, the
		bitmap image is drawn at 100% scale, snapped to the nearest pixel.
		When targeting Flash Player, this value allows the image to be drawn as fast
		as possible using the internal vector renderer.

	**/
	public var pixelSnapping:PixelSnapping;

	/**
		Controls whether or not the bitmap is smoothed when scaled. If
		`true`, the bitmap is smoothed when scaled. If
		`false`, the bitmap is not smoothed when scaled.
	**/
	public var smoothing:Bool;
	#end

	@:noCompletion private var __width:Int = 0;
	@:noCompletion private var __height:Int = 0;

	@:noCompletion private var __bitmapData:BitmapData;
	@:noCompletion private var __texture:TextureBase;

	@:noCompletion private var __appClass:Class<Dynamic>;
	@:noCompletion private var __engine:Engine;
	@:noCompletion private var __window:Window;
	@:noCompletion private var __cullingState:Face = None;

	@:noCompletion private var __mousePoint:Point = new Point();
	@:noCompletion private var __localPoint:Point = new Point();
	#if flash
	@:noCompletion private var __heapsRenderbufferProgram:Program3D;
	@:noCompletion private var __context3D:Context3D;
	@:noCompletion private var __heapsRenderbufferTexture:openfl.display3D.textures.RectangleTexture;
	@:noCompletion private var __vertexBufferData:Vector<Float> = new Vector<Float>([0, 600, 0, 0, 1, 0, 0, 0, 0, 0, 800, 0, 0, 1, 0, 800, 600, 0, 1, 1]);
	@:noCompletion private var __indexBufferData:Vector<UInt> = new Vector<UInt>([0, 1, 2, 0, 2, 3]);
	@:noCompletion private var __vertexBuffer:VertexBuffer3D;
	@:noCompletion private var __indexBuffer:IndexBuffer3D;
	@:noCompletion private var __projection:Matrix3D = new Matrix3D();
	@:noCompletion private var __transform:Matrix3D = new Matrix3D();
	#end

	public var __renderTarget:Texture;

	public var appInstance:Dynamic;

	public function new(appClass:Class<Dynamic>)
	{
		__appClass = appClass;

		super();

		#if !flash
		__type = HEAPS_CONTAINER;
		#end

		Window.CURRENT = Lib.application;

		if (__appClass != null) appInstance = cast Type.createEmptyInstance(__appClass);

		addEventListener(openfl.events.Event.ADDED_TO_STAGE, __onAddedToStage);
	}

	private function __onAddedToStage(e:openfl.events.Event)
	{
		// Create instance of Heaps app on delay to avoid blocking
		haxe.Timer.delay(initHeapsApp, 0);
	}

	private function initHeapsApp()
	{
		if (__appClass != null && Window.CURRENT != null)
		{
			hxd.System.start(function()
			{
				stage.addEventListener(openfl.events.Event.RESIZE, __onResize);
				stage.addEventListener(MouseEvent.MOUSE_MOVE, __onMouseMove);
				#if !js
				stage.addEventListener(MouseEvent.MOUSE_DOWN, __onMouseDown);
				stage.addEventListener(MouseEvent.MOUSE_UP, __onMouseUp);
				stage.addEventListener(MouseEvent.MOUSE_WHEEL, __onMouseWheel);
				#end

				__engine = appInstance.engine = @:privateAccess new h3d.Engine();
				__window = Window.getInstance();
				__engine.onReady = __onEngineReady;
				__engine.init();
			});
		}
		else
		{
			trace("Lime Window.CURRENT not set. Heaps App will not be able to render to this Lime backend. Wait for 'onWindowCreate' to complete.");
		}
	}

	private function __onEngineReady()
	{
		appInstance.setup();
		__onResize(null);

		#if flash
		FlashRenderer.register(this);
		#end

		dispatchEvent(new openfl.events.Event(openfl.events.Event.COMPLETE));
	}

	@:noCompletion #if !flash override #end private function __enterFrame(deltaTime:Int):Void
	{
		if (__engine != null)
		{
			if (appInstance != null && appInstance.s2d != null && appInstance.s3d != null && __renderTarget != null)
			{
				__engine.pushTarget(__renderTarget);

				// Ensure all the cached render states are cleared for a new render
				@:privateAccess __engine.needFlushTarget = true;
				#if flash
				var driver:h3d.impl.Stage3dDriver = cast __engine.driver;
				driver.curAttributes = 0;
				Lib.current.stage.stage3Ds[0].context3D.setCulling(appInstance.s3d.renderer.lastCullingState == h3d.mat.Data.Face.Front ? "front" : "back");
				#else
				var driver:h3d.impl.GlDriver = cast __engine.driver;
				driver.curIndexBuffer = null;
				driver.curAttribs = [];
				@:privateAccess stage.context3D.__setGLFrontFace(appInstance.s3d.renderer.lastCullingState == h3d.mat.Data.Face.Front ? true : false);
				#end
				driver.curColorMask = -1;
				driver.curMatBits = -1;
				driver.curShader = null;
				driver.curBuffer = null;

				__engine.driver.begin(hxd.Timer.frameCount);

				__engine.clear(0, 1, 1); // Clears the render target texture and depth buffer

				appInstance.s3d.render(__engine);
				appInstance.s2d.render(__engine);

				__engine.popTarget();

				__engine.clear(0, 1, 1); // Clears the render target texture and depth buffer

				#if (!js && !flash)
				@:privateAccess System.mainLoop();
				#end

				#if !flash
				// Modify the texture ID to point to the Heaps render target texture to bind it correctly
				@:privateAccess __texture.__textureID = __renderTarget.t.t;

				__setRenderDirty();
				#else
				@:privateAccess __heapsRenderbufferTexture = cast __renderTarget.t;
				#end
			}
		}
	}

	private function setupRenderTarget()
	{
		if (__renderTarget != null)
		{
			heapsRenderTargets.remove(__renderTarget);

			__renderTarget.depthBuffer.dispose();
			__renderTarget.dispose();
			if (__bitmapData != null) __bitmapData.dispose();
			if (__texture != null) __texture.dispose();
		}

		// Create render target and depth buffer for Heaps rendering
		var w = __width;
		var h = __height;
		__renderTarget = new Texture(w, h, [TextureFlags.Target]);
		#if !flash
		__renderTarget.depthBuffer = new DepthBuffer(w, h);
		#else
		__renderTarget.depthBuffer = new DepthBuffer(-1, -1);
		#end

		heapsRenderTargets.push(__renderTarget);

		// Create a fake OpenFl bitmap data to allow integrating the renderTarget texture into the OpenFL rendering pipeline.
		__bitmapData = new BitmapData(w, h, true, 0x80ff0000);
		#if !flash
		__texture = __bitmapData.getTexture(stage.context3D);
		#else
		__projection.identity();
		var raw = __projection.rawData;
		var st = Lib.current.stage;

		var sx = 1.0 / st.stageWidth;
		var sy = 1.0 / -st.stageHeight;
		var sz = 1.0 / 2000;

		raw[0] = 2 * sx;
		raw[5] = 2 * sy;
		raw[10] = -2 * sz;

		raw[12] = -st.stageWidth * sx;
		raw[13] = -st.stageHeight * sy;
		__projection.rawData = raw;

		var vertexAssembler = new AGALMiniAssembler();
		vertexAssembler.assemble(Context3DProgramType.VERTEX, "m44 op, va0, vc0\n" + "mov v0, va1" #if heaps, 2 #end);

		var fragmentAssembler = new AGALMiniAssembler();
		fragmentAssembler.assemble(Context3DProgramType.FRAGMENT, "tex ft0, v0, fs0 <2d,nearest,nomip>\n" + "mov oc, ft0.rgb" #if heaps, 2 #end);

		var driver:h3d.impl.Stage3dDriver = cast __engine.driver;
		__context3D = driver.ctx;

		__heapsRenderbufferTexture = __context3D.createRectangleTexture(__bitmapData.width, __bitmapData.height, 'bgra', true);
		__heapsRenderbufferTexture.uploadFromBitmapData(__bitmapData);

		__vertexBuffer = __context3D.createVertexBuffer(4, 5);
		__vertexBufferData[10] = __vertexBufferData[15] = __width;
		__vertexBufferData[1] = __vertexBufferData[16] = __height;
		__vertexBuffer.uploadFromVector(__vertexBufferData, 0, 4);
		__indexBuffer = __context3D.createIndexBuffer(6);
		__indexBuffer.uploadFromVector(__indexBufferData, 0, 6);

		__heapsRenderbufferProgram = __context3D.createProgram();
		__heapsRenderbufferProgram.upload(vertexAssembler.agalcode, fragmentAssembler.agalcode);
		#end
	}

	#if flash
	@:noCompletion private function __renderFlash():Void
	{
		__enterFrame(0);
		FlashHeaps.render(this);
	}
	#end

	@:keep @:noCompletion private function __onResize(e:openfl.events.Event)
	{
		__width = __width == 0 ? Lib.current.stage.stageWidth : __width;
		__height = __height == 0 ? Lib.current.stage.stageHeight : __height;

		if (appInstance != null && __engine != null && __engine.mem != null)
		{
			setupRenderTarget();

			__engine.width = __width;
			__engine.height = __height;
			#if flash
			var driver:h3d.impl.Stage3dDriver = cast Engine.getCurrent().driver;
			@:privateAccess driver.ctx.configureBackBuffer(Std.int(Lib.current.stage.stageWidth), Std.int(Lib.current.stage.stageHeight), driver.antiAlias);
			driver.width = __width;
			driver.height = __height;
			#else
			__engine.driver.resize(__width, __height);
			#end
			__window.windowWidth = __width;
			__window.windowHeight = __height;
			__engine.onWindowResize();
		}
	}

	@:keep @:noCompletion private function __onMouseDown(me:MouseEvent):Void
	{
		if (__localPoint.x > 0 && __localPoint.x < __width && __localPoint.y > 0 && __localPoint.y < __height)
		{
			var e = new Event(EPush, __localPoint.x, __localPoint.y);
			appInstance.sevents.onEvent(e);
		}
	}

	@:keep @:noCompletion private function __onMouseMove(me:MouseEvent)
	{
		__mousePoint.x = me.localX;
		__mousePoint.y = me.localY;
		__localPoint = globalToLocal(__mousePoint);

		if (__localPoint.x > 0 && __localPoint.x < __width && __localPoint.y > 0 && __localPoint.y < __height)
		{
			#if (js || flash)
			@:privateAccess __window.openFLMouseX = __localPoint.x;
			@:privateAccess __window.openFLMouseY = __localPoint.y;
			#else
			appInstance.sevents.setMousePos(__localPoint.x, __localPoint.y);
			#end
			appInstance.sevents.onEvent(new Event(EMove, __localPoint.x, __localPoint.y));
		}
	}

	@:keep @:noCompletion private function __onMouseUp(me:MouseEvent):Void
	{
		if (__localPoint.x > 0 && __localPoint.x < __width && __localPoint.y > 0 && __localPoint.y < __height)
		{
			var e = new Event(ERelease, __localPoint.x, __localPoint.y);
			appInstance.sevents.onEvent(e);
		}
	}

	@:keep @:noCompletion private function __onMouseWheel(me:MouseEvent):Void
	{
		if (__localPoint.x > 0 && __localPoint.x < __width && __localPoint.y > 0 && __localPoint.y < __height)
		{
			if (me.delta != 0)
			{
				var e = new Event(EWheel, __localPoint.x, __localPoint.y);
				e.wheelDelta = me.delta;
				appInstance.sevents.onEvent(e);
			}
		}
	}

	@:getter(height)
	@:noCompletion #if !flash override #end private function get_height():Float
	{
		return __height;
	}

	@:setter(height)
	@:noCompletion #if !flash override #end private function set_height(value:Float)
	{
		__height = Std.int(value);
		__onResize(null);

		#if !flash
		return value;
		#end
	}

	@:getter(width)
	@:noCompletion #if !flash override #end private function get_width():Float
	{
		return __width;
	}

	@:setter(width)
	@:noCompletion #if !flash override #end private function set_width(value:Float)
	{
		__width = Std.int(value);
		__onResize(null);

		#if !flash
		return value;
		#end
	}
}
#else
// Null Bitmap class when heaps is not defined

@:access(flash.display.Bitmap)
class HeapsContainer extends openfl.display.Bitmap
{
	@:noCompletion private var __appClass:Class<Dynamic>;

	public function new(appClass:Class<Dynamic>)
	{
		super();
		throw "Heaps library is not referenced in project.xml. Please add '<haxelib name=\"heaps\" />' and '<haxelib name=\"hxbit\" />'";
	}
}
#end
