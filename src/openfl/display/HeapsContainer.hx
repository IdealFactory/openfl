package openfl.display;

import openfl._internal.renderer.context3D.Context3DHeaps;
import openfl.display3D.textures.TextureBase;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.events.RenderEvent;
import openfl.geom.Point;
import openfl.Lib;
import h3d.Engine;
import h3d.mat.Data;
import h3d.mat.DepthBuffer;
import h3d.mat.Texture;
import hxd.System;
import hxd.Window;
import hxd.Event;

@:access(openfl.display3D.Context3D)
@:access(hxd.Window)
@:access(h3d.impl.GlDriver)
class HeapsContainer extends DisplayObject
{
	public static var heapsRenderTargets:Array<Texture> = [];

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

	public var __renderTarget:Texture;

	public var appInstance:Dynamic;

	public function new(appClass:Class<Dynamic>)
	{
		__appClass = appClass;

		super();

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

		dispatchEvent(new openfl.events.Event(openfl.events.Event.COMPLETE));
	}

	@:noCompletion private override function __enterFrame(deltaTime:Int):Void
	{
		if (__engine != null)
		{
			if (appInstance != null && appInstance.s2d != null && appInstance.s3d != null && __renderTarget != null)
			{
				__engine.pushTarget(__renderTarget);

				// Ensure all the cached render states are cleared for a new render
				@:privateAccess __engine.needFlushTarget = true;
				var glDriver:h3d.impl.GlDriver = cast __engine.driver;
				glDriver.curColorMask = -1;
				glDriver.curMatBits = -1;
				glDriver.curIndexBuffer = null;
				glDriver.curShader = null;
				glDriver.curBuffer = null;
				glDriver.curAttribs = [];

				@:privateAccess stage.context3D.__setGLFrontFace(appInstance.s3d.renderer.lastCullingState == h3d.mat.Data.Face.Front ? true : false);

				__engine.driver.begin(hxd.Timer.frameCount);

				__engine.clear(0, 1, 1); // Clears the render target texture and depth buffer

				appInstance.s3d.render(__engine);
				appInstance.s2d.render(__engine);

				__engine.popTarget();

				#if (!js && !flash)
				@:privateAccess System.mainLoop();
				#end

				// Modify the texture ID to point to the Heaps render target texture to bind it correctly
				@:privateAccess __texture.__textureID = __renderTarget.t.t;

				__setRenderDirty();
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
		__renderTarget.depthBuffer = new DepthBuffer(w, h);

		heapsRenderTargets.push(__renderTarget);

		// Create a fake OpenFl bitmap data to allow integrating the renderTarget texture into the OpenFL rendering pipeline.
		__bitmapData = new BitmapData(w, h, true, 0x80ff0000);
		__texture = __bitmapData.getTexture(stage.context3D);
	}

	@:noCompletion private override function __renderGL(renderer:OpenGLRenderer):Void
	{
		Context3DHeaps.render(this, renderer);

		__renderEvent(renderer);
	}

	@:keep @:noCompletion private function __onResize(e:openfl.events.Event)
	{
		__width = __width == 0 ? Lib.current.stage.stageWidth : __width;
		__height = __height == 0 ? Lib.current.stage.stageHeight : __height;

		if (appInstance != null && __engine != null && __engine.mem != null)
		{
			setupRenderTarget();

			__engine.resize(__width, __height);
			@:privateAccess __window.windowWidth = __width;
			@:privateAccess __window.windowHeight = __height;
			@:privateAccess __engine.onWindowResize();
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
			#if js
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

	@:noCompletion private override function get_height():Float
	{
		return __height;
	}

	@:noCompletion private override function set_height(value:Float):Float
	{
		__height = Std.int(value);
		__onResize(null);

		return value;
	}

	@:noCompletion private override function get_width():Float
	{
		return __width;
	}

	@:noCompletion private override function set_width(value:Float):Float
	{
		__width = Std.int(value);
		__onResize(null);

		return value;
	}
}
