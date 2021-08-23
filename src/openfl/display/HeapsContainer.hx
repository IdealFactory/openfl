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
#end
import openfl._internal.renderer.context3D.Context3DState;
import openfl.display3D.textures.TextureBase;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.events.MouseEvent;
import openfl.events.TouchEvent;
import openfl.events.RenderEvent;
import openfl.geom.Matrix;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.Lib;
#if (heaps && !macro)
import h3d.Engine;
import h3d.mat.Data;
import h3d.mat.DepthBuffer;
import h3d.mat.Texture;
import hxd.System;
import hxd.Window;
import hxd.Event;
import format.png.Data;
import format.png.Writer;
import lime._internal.format.Zlib;
import haxe.io.Bytes;
import haxe.io.BytesOutput;

@:access(openfl.display3D.Context3D)
@:access(openfl.geom.Matrix)
@:access(openfl.geom.Rectangle)
@:access(hxd.Window)
@:access(h3d.Engine)
@:access(h3d.impl.GlDriver)
@:access(h3d.impl.Stage3dDriver)
class HeapsContainer extends #if !flash Sprite #else Bitmap implements IDisplayObject #end
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

	@:noCompletion private var __x:Int = -1;
	@:noCompletion private var __y:Int = -1;
	@:noCompletion private var __width:Int = 0;
	@:noCompletion private var __height:Int = 0;

	@:noCompletion private var __bitmapData:BitmapData;
	@:noCompletion private var __texture:TextureBase;

	@:noCompletion private var __appClass:Class<Dynamic>;
	@:noCompletion private var __engine:Engine;
	@:noCompletion private var __window:Window;
	@:noCompletion private var __cullingState:Face = None;
	@:noCompletion private var __stateStore:Context3DState;
	@:noCompletion private var __heapsDirty:Bool = true;

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
	@:noCompletion private var __tempMatrix = new Matrix();
	@:noCompletion private var __tempMatrix2 = new Matrix();
	@:noCompletion private var __tempRectangle = new Rectangle();
	#end

	public var __renderTarget:Texture;

	static var __rttQueue:Array<Void->Void>;
	static var __rttCallbackQueue:Array<Void->Void>;

	public var appInstance:Dynamic;
	public var backgroundColor:UInt = 0x0;

	var __autoUpdate:Bool;

	public function new(appClass:Class<Dynamic>, autoUpdate:Bool = true)
	{
		__appClass = appClass;
		__autoUpdate = autoUpdate;

		__rttQueue = [];
		__rttCallbackQueue = [];

		super();

		#if !flash
		__type = HEAPS_CONTAINER;
		#end

		var attributes = Lib.application.window.context.attributes;
		h3d.Engine.ANTIALIASING = attributes.antialiasing;

		Window.CURRENT = Lib.application;

		if (__appClass != null) appInstance = cast Type.createEmptyInstance(__appClass);

		// Create instance of Heaps app on delay to avoid blocking
		haxe.Timer.delay(initHeapsApp, 5);
	}

	public static function addRTTFunc(rttFunc:Void->Void, callback:Void->Void)
	{
		__rttQueue.push(rttFunc);
		__rttCallbackQueue.push(callback);
	}

	private function initHeapsApp()
	{
		if (__appClass != null && Window.CURRENT != null)
		{
			hxd.System.start(function()
			{
				Lib.current.stage.addEventListener(openfl.events.Event.RESIZE, __onResize);
				this.addEventListener(MouseEvent.MOUSE_MOVE, __onMouseMove);
				this.addEventListener(MouseEvent.MOUSE_DOWN, __onMouseDown);
				this.addEventListener(MouseEvent.MOUSE_UP, __onMouseUp);
				this.addEventListener(MouseEvent.MOUSE_WHEEL, __onMouseWheel);
				this.addEventListener(TouchEvent.TOUCH_MOVE, __onTouchMove);
				this.addEventListener(TouchEvent.TOUCH_BEGIN, __onTouchBegin);
				this.addEventListener(TouchEvent.TOUCH_END, __onTouchEnd);
				Lib.current.stage.addEventListener(KeyboardEvent.KEY_DOWN, __onKeyDown);
				Lib.current.stage.addEventListener(KeyboardEvent.KEY_UP, __onKeyUp);

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

	public static function syncedRenderCalls():Void
	{
		if (__rttQueue != null && __rttQueue.length > 0)
		{
			var ctx3d = Lib.current.stage.context3D;
			var __stateStore:openfl._internal.renderer.context3D.Context3DState = null;
			if (ctx3d.__state != null) __stateStore = ctx3d.__state.clone();

			#if !android
			var preMultValue = @:privateAccess ctx3d.gl.getParameter(lime.graphics.opengl.GL.UNPACK_PREMULTIPLY_ALPHA_WEBGL);
			@:privateAccess ctx3d.gl.pixelStorei(lime.graphics.opengl.GL.UNPACK_PREMULTIPLY_ALPHA_WEBGL, 0);
			#end
			@:privateAccess ctx3d.gl.disable(lime.graphics.opengl.GL.STENCIL_TEST);

			for (rttFunc in __rttQueue)
			{
				rttFunc();
			}

			#if !android
			@:privateAccess ctx3d.gl.pixelStorei(lime.graphics.opengl.GL.UNPACK_PREMULTIPLY_ALPHA_WEBGL, preMultValue);
			@:privateAccess ctx3d.gl.enable(lime.graphics.opengl.GL.STENCIL_TEST);
			#end

			if (__stateStore != null) ctx3d.__state.fromState(__stateStore);

			__rttQueue = [];
		}

		if (__rttCallbackQueue != null && __rttCallbackQueue.length > 0)
		{
			for (callbackFunc in __rttCallbackQueue)
			{
				if (callbackFunc != null) callbackFunc();
			}
			__rttCallbackQueue = [];
		}
	}

	public function updateContainer():Void
	{
		if ((__heapsDirty || __autoUpdate) && __engine != null)
		{
			if (appInstance != null && appInstance.s2d != null && appInstance.s3d != null)
			{
				__heapsDirty = false;

				if (Std.int(x) != __x || Std.int(y) != __y) __engine.offset(Std.int(x), Lib.current.stage.stageHeight - __height - Std.int(y));

				__x = Std.int(x);
				__y = Std.int(y);

				__engine.driver.begin(hxd.Timer.frameCount);

				#if (!js && !flash)
				@:privateAccess System.mainLoop();
				#else
				@:privateAccess System.loopFunc();
				#end
			}
		}
	}

	public function renderContainer():Void
	{
		if ((__heapsDirty || __autoUpdate) && __engine != null)
		{
			if (appInstance != null && appInstance.s2d != null && appInstance.s3d != null)
			{
				__heapsDirty = false;

				#if !flash
				if (Lib.current.stage.context3D.__state != null) __stateStore = Lib.current.stage.context3D.__state.clone();
				#end

				var stg = Lib.current.stage;
				var ctx = Lib.current.stage.context3D;

				// Ensure all the cached render states are cleared for a new render
				@:privateAccess __engine.needFlushTarget = true;

				#if flash
				var driver:h3d.impl.Stage3dDriver = cast __engine.driver;
				driver.curAttributes = 0;
				Lib.current.stage.stage3Ds[0].context3D.setCulling(appInstance.s3d.renderer.lastCullingState == h3d.mat.Data.Face.Front ? "front" : "back");
				#else
				var driver:h3d.impl.GlDriver = cast h3d.Engine.getCurrent().driver;
				driver.curIndexBuffer = null;
				driver.curAttribs = [];
				driver.curAttribs = [];
				driver.curStOpBits = -1;
				driver.curStMaskBits = -1;
				driver.curMatBits = -1;
				#end

				@:privateAccess if (ctx.__stage3D == null) ctx.clear(0, 0, 0, 0, 1, 0, openfl.display3D.Context3DClearMask.DEPTH);

				var gl = openfl.Lib.current.stage.context3D.gl;

				appInstance.s3d.render(__engine);
				appInstance.s2d.render(__engine);

				@:privateAccess __engine.doFlushTarget();

				@:privateAccess ctx.__stage.__renderer.__cleared = ctx.__cleared = true;

				#if !flash
				if (__stateStore != null) ctx.__state.fromState(__stateStore);
				ctx.__contextState.stateDirty = true;
				#end
			}
		}
	}

	public function render():Void
	{
		__heapsDirty = true;
	}

	public function capture(w:Int, h:Int, msaaLevel:Int = 4)
	{
		if (__engine != null)
		{
			if (appInstance != null && appInstance.s2d != null && appInstance.s3d != null)
			{
				// Ensure all the cached render states are cleared for a new render
				@:privateAccess __engine.needFlushTarget = true;

				var oldX = __x;
				var oldY = __y;
				var oldW = __width;
				var oldH = __height;

				var stg = Lib.current.stage;
				var ctx = Lib.current.stage.context3D;

				// Ensure all the cached render states are cleared for a new render
				@:privateAccess __engine.needFlushTarget = true;

				#if flash
				var destTarget:Texture;
				destTarget = new Texture(w, h, [TextureFlags.Target]#if !flash, hxd.PixelFormat.RGBA #end);
				destTarget.depthBuffer = new DepthBuffer(-1, -1);

				__engine.pushTarget(destTarget);

				var driver:h3d.impl.Stage3dDriver = cast Engine.getCurrent().driver;
				driver.width = w;
				driver.height = h;
				driver.curAttributes = 0;
				Lib.current.stage.stage3Ds[0].context3D.setCulling("front");

				appInstance.s3d.render(__engine);
				appInstance.s2d.render(__engine);
				#else
				var destTarget:Texture;
				var driver:h3d.impl.GlDriver = cast __engine.driver;

				if (ctx.__state != null) __stateStore = ctx.__state.clone();

				if (!__engine.driver.hasFeature(ShaderModel3))
				{
					destTarget = new Texture(w, h, [TextureFlags.Target], hxd.PixelFormat.RGBA);

					var captureTarget = new Texture(w, h, [TextureFlags.Target], hxd.PixelFormat.RGBA);
					captureTarget.depthBuffer = new DepthBuffer(w, h);

					// destTarget = new Texture(w, h, [TextureFlags.Target], hxd.PixelFormat.RGBA);
					// destTarget.depthBuffer = new DepthBuffer(w, h);

					if (Std.is(appInstance.s3d.renderer, h3d.scene.fwd.PBRSinglePassRenderer))
					{
						appInstance.s3d.renderer.enableFXAA = true;
					}

					__engine.pushTarget(captureTarget);

					driver.curIndexBuffer = null;
					driver.curAttribs = [];
					driver.curAttribs = [];
					driver.curStOpBits = -1;
					driver.curStMaskBits = -1;
					driver.curMatBits = -1;
					driver.resize(w, h);

					__engine.clear(1, 1, 1); // Clears the render target texture and depth buffer

					__engine.setRenderZone(0, 0, w, h);

					@:privateAccess ctx.__setGLFrontFace(true);

					appInstance.s3d.render(__engine);
					appInstance.s2d.render(__engine);

					if (Std.is(appInstance.s3d.renderer, h3d.scene.fwd.PBRSinglePassRenderer))
					{
						appInstance.s3d.renderer.enableFXAA = false;
					}

					var fxaa = new h3d.pass.FXAA();
					__engine.pushTarget(destTarget);
					fxaa.apply(captureTarget);
				}
				else
				{
					destTarget = new Texture(w, h, [TextureFlags.Target], hxd.PixelFormat.BGRA);

					var captureTarget:Texture;
					captureTarget = new Texture(w, h, [TextureFlags.Target], hxd.PixelFormat.BGRA);
					captureTarget.depthBuffer = new DepthBuffer(w, h, Depth16, msaaLevel);
					captureTarget.customFBO = __engine.driver.createFrameBuffer(w, h, msaaLevel);

					var msaaTarget:Texture;
					msaaTarget = new Texture(w, h, [TextureFlags.Target], hxd.PixelFormat.BGRA);
					msaaTarget.depthBuffer = new DepthBuffer(w, h, Depth16, msaaLevel);
					msaaTarget.msaaBuffer = __engine.driver.createFrameBuffer(w, h, msaaLevel);

					__engine.pushTarget(msaaTarget);
					__engine.width = w;
					__engine.height = h;

					driver.curIndexBuffer = null;
					driver.curAttribs = [];
					driver.curAttribs = [];
					driver.curStOpBits = -1;
					driver.curStMaskBits = -1;
					driver.curMatBits = -1;
					driver.resize(w, h);

					__engine.clear(1, 1, 1); // Clears the render target texture and depth buffer

					__engine.setRenderZone(0, 0, w, h);

					@:privateAccess ctx.__setGLFrontFace(true);

					appInstance.s3d.render(__engine);
					appInstance.s2d.render(__engine);

					// Blit the rendered multi-sample FBO to the target texture
					driver.blitFramebuffer(msaaTarget.msaaBuffer, captureTarget.customFBO, destTarget, w, h);
				}
				#end

				var pixels = destTarget.capturePixels();
				var bmd = new hxd.BitmapData(pixels.width, pixels.height);
				bmd.setPixels(pixels);

				__engine.popTarget();

				__engine.width = oldW;
				__engine.height = oldH;
				__engine.setRenderZone(oldX, oldY, oldW, oldH);

				__engine.clear(1, 1, 1);

				#if flash
				driver.width = oldW;
				driver.height = oldH;
				#else
				@:privateAccess ctx.__stage.__renderer.__cleared = ctx.__cleared = true;
				@:privateAccess __engine.doFlushTarget();

				driver.resize(oldW, oldH);
				if (__stateStore != null && ctx.__state != null) ctx.__state.fromState(__stateStore);
				ctx.__contextState.stateDirty = true;
				#end

				return /*new BitmapData(w, h, false, 0);*/ #if !flash BitmapData.fromImage(bmd.toNative(), true) #else bmd.toNative() #end;
			}
		}
		return null;
	}

	public static function toPNG(w, h, sourceBytes):Bytes
	{
		var bytes = Bytes.alloc(w * h * 4 + h);
		var sourceIndex:Int, index:Int;

		for (y in 0...h)
		{
			sourceIndex = y * w * 4;
			index = y * w * 4 + y;

			bytes.set(index, 0);
			bytes.blit(index + 1, sourceBytes, sourceIndex, w * 4);
		}

		var data = new List();
		data.add(CHeader({
			width: w,
			height: h,
			colbits: 8,
			color: ColTrue(true),
			interlaced: false
		}));
		data.add(CData(Zlib.compress(bytes)));
		data.add(CEnd);

		var output = new BytesOutput();
		var png = new Writer(output);
		png.write(data);

		return output.getBytes();
	}

	#if flash
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
		__renderTarget.depthBuffer = new DepthBuffer(-1, -1);

		heapsRenderTargets.push(__renderTarget);

		// Create a fake OpenFl bitmap data to allow integrating the renderTarget texture into the OpenFL rendering pipeline.
		var st = Lib.current.stage;
		__bitmapData = new BitmapData(w, h, true, 0x80ff0000);
		__projection.identity();
		var raw = __projection.rawData;

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
	}

	@:noCompletion private function __renderFlash():Void
	{
		__enterFrame(0);
		FlashHeaps.render(this);
	}
	#end

	#if flash
	public override function hitTestPoint(x:Float, y:Float, shapeFlag:Bool = false):Bool
	{
		if (stage != null)
		{
			return __hitTest(x, y, shapeFlag, null, false, this);
		}
		else
		{
			return false;
		}
	}

	public override function getBounds(targetCoordinateSpace:DisplayObject):Rectangle
	{
		var matrix = __tempMatrix;

		if (targetCoordinateSpace != null && targetCoordinateSpace != this)
		{
			matrix.copyFrom(this.transform.matrix);

			var targetMatrix = __tempMatrix2;

			targetMatrix.copyFrom(targetCoordinateSpace.transform.matrix);
			targetMatrix.invert();

			matrix.concat(targetMatrix);
		}
		else
		{
			matrix.identity();
		}

		var bounds = new Rectangle();
		__getBounds(bounds, matrix);

		return bounds;
	}
	#end

	@:noCompletion
	private #if !flash override #end function __getBounds(rect:Rectangle, matrix:Matrix):Void
	{
		if (__bitmapData == null) return;

		var bounds = #if flash __tempRectangle #else Rectangle.__pool.get() #end;
		bounds.setTo(0, 0, __bitmapData.width, __bitmapData.height);

		#if flash
		__transformBounds(bounds, matrix);
		bounds = bounds.union(rect);
		rect.setTo(bounds.x, bounds.y, bounds.width, bounds.height);
		#else
		bounds.__transform(bounds, matrix);
		rect.__expand(bounds.x, bounds.y, bounds.width, bounds.height);
		Rectangle.__pool.release(bounds);
		#end
	}

	@:noCompletion
	private #if !flash override #end function __hitTest(x:Float, y:Float, shapeFlag:Bool, stack:Array<DisplayObject>, interactiveOnly:Bool,
			hitObject:DisplayObject):Bool
	{
		#if !flash
		if (!hitObject.visible || __isMask) return false;
		if (mask != null && !mask.__hitTestMask(x, y)) return false;
		__getRenderTransform();
		var px = __renderTransform.__transformInverseX(x, y);
		var py = __renderTransform.__transformInverseY(x, y);
		#else
		if (!hitObject.visible || __bitmapData == null) return false;
		if (mask != null && !mask.hitTestPoint(x, y)) return false;
		var px = __transformInverseX(this.transform.matrix, x, y);
		var py = __transformInverseY(this.transform.matrix, x, y);
		#end
		#if !flash
		if (__scrollRect != null && !__scrollRect.contains(px, py))
		#else
		if (scrollRect != null && !scrollRect.contains(px, py))
		#end
		{
			return false;
		}
		if (stack != null && px > 0 && py > 0 && px <= width && py <= height)
		{
			stack.push(hitObject);
			return true;
		}
		return false;
	}

	@:noCompletion
	private #if !flash override #end function __hitTestMask(x:Float, y:Float):Bool
	{
		#if !flash
		__getRenderTransform();
		var px = __renderTransform.__transformInverseX(x, y);
		var py = __renderTransform.__transformInverseY(x, y);
		#else
		var px = __transformInverseX(this.transform.matrix, x, y);
		var py = __transformInverseY(this.transform.matrix, x, y);
		#end
		if (px > 0 && py > 0 && px <= width && py <= height)
		{
			return true;
		}
		return false;
	}

	#if flash
	@:noCompletion private inline function __transformBounds(_rect:Rectangle, m:Matrix):Void
	{
		var tx0 = m.a * _rect.x + m.c * _rect.y;
		var tx1 = tx0;
		var ty0 = m.b * _rect.x + m.d * _rect.y;
		var ty1 = ty0;

		var tx = m.a * (_rect.x + _rect.width) + m.c * _rect.y;
		var ty = m.b * (_rect.x + _rect.width) + m.d * _rect.y;

		if (tx < tx0) tx0 = tx;
		if (ty < ty0) ty0 = ty;
		if (tx > tx1) tx1 = tx;
		if (ty > ty1) ty1 = ty;

		tx = m.a * (_rect.x + _rect.width) + m.c * (_rect.y + _rect.height);
		ty = m.b * (_rect.x + _rect.width) + m.d * (_rect.y + _rect.height);

		if (tx < tx0) tx0 = tx;
		if (ty < ty0) ty0 = ty;
		if (tx > tx1) tx1 = tx;
		if (ty > ty1) ty1 = ty;

		tx = m.a * _rect.x + m.c * (_rect.y + _rect.height);
		ty = m.b * _rect.x + m.d * (_rect.y + _rect.height);

		if (tx < tx0) tx0 = tx;
		if (ty < ty0) ty0 = ty;
		if (tx > tx1) tx1 = tx;
		if (ty > ty1) ty1 = ty;

		_rect.setTo(tx0 + m.tx, ty0 + m.ty, tx1 - tx0, ty1 - ty0);
	}

	@:noCompletion private inline function __transformInverseX(_matrix:Matrix, px:Float, py:Float):Float
	{
		var norm = _matrix.a * _matrix.d - _matrix.b * _matrix.c;

		if (norm == 0)
		{
			return -_matrix.tx;
		}
		else
		{
			return (1.0 / norm) * (_matrix.c * (_matrix.ty - py) + _matrix.d * (px - _matrix.tx));
		}
	}

	@:noCompletion private inline function __transformInverseY(_matrix:Matrix, px:Float, py:Float):Float
	{
		var norm = _matrix.a * _matrix.d - _matrix.b * _matrix.c;

		if (norm == 0)
		{
			return -_matrix.ty;
		}
		else
		{
			return (1.0 / norm) * (_matrix.a * (py - _matrix.ty) + _matrix.b * (_matrix.tx - px));
		}
	}
	#end

	@:keep @:noCompletion private function __onResize(e:openfl.events.Event)
	{
		__width = __width == 0 ? Lib.current.stage.stageWidth : __width;
		__height = __height == 0 ? Lib.current.stage.stageHeight : __height;

		if (appInstance != null && __engine != null && __engine.mem != null)
		{
			#if flash
			setupRenderTarget();
			#end

			__engine.width = __width;
			__engine.height = __height;
			#if flash
			var driver:h3d.impl.Stage3dDriver = cast Engine.getCurrent().driver;
			@:privateAccess driver.ctx.configureBackBuffer(Std.int(Lib.current.stage.stageWidth), Std.int(Lib.current.stage.stageHeight), driver.antiAlias);
			driver.width = __width;
			driver.height = __height;
			#else
			__engine.offset(Std.int(x), Lib.current.stage.stageHeight - __height - Std.int(y));
			__engine.resize(__width, __height);
			#end
			__window.windowWidth = __width;
			__window.windowHeight = __height;
			__engine.onWindowResize();
		}
	}

	@:keep @:noCompletion private function __onMouseDown(me:MouseEvent):Void
	{
		__mousePoint.x = me.localX;
		__mousePoint.y = me.localY;

		if (__mousePoint.x > 0 && __mousePoint.x < __width && __mousePoint.y > 0 && __mousePoint.y < __height)
		{
			var e = new Event(EPush, __mousePoint.x, __mousePoint.y);
			appInstance.sevents.onEvent(e);
		}
	}

	@:keep @:noCompletion private function __onMouseMove(me:MouseEvent)
	{
		__mousePoint.x = me.localX;
		__mousePoint.y = me.localY;

		if (__mousePoint.x > 0 && __mousePoint.x < __width && __mousePoint.y > 0 && __mousePoint.y < __height)
		{
			#if (js || flash)
			@:privateAccess __window.openFLMouseX = __mousePoint.x;
			@:privateAccess __window.openFLMouseY = __mousePoint.y;
			#else
			appInstance.sevents.setMousePos(__mousePoint.x, __mousePoint.y);
			#end
			appInstance.sevents.onEvent(new Event(EMove, __mousePoint.x, __mousePoint.y));
			__heapsDirty = true;
		}
	}

	@:keep @:noCompletion private function __onMouseUp(me:MouseEvent):Void
	{
		__mousePoint.x = me.localX;
		__mousePoint.y = me.localY;

		if (__mousePoint.x > 0 && __mousePoint.x < __width && __mousePoint.y > 0 && __mousePoint.y < __height)
		{
			var e = new Event(ERelease, __mousePoint.x, __mousePoint.y);
			appInstance.sevents.onEvent(e);
		}
	}

	@:keep @:noCompletion private function __onMouseWheel(me:MouseEvent):Void
	{
		if (__mousePoint.x > 0 && __mousePoint.x < __width && __mousePoint.y > 0 && __mousePoint.y < __height)
		{
			if (me.delta != 0)
			{
				var e = new Event(EWheel, __mousePoint.x, __mousePoint.y);
				e.wheelDelta = -me.delta #if js / 120 #end; // Similar division as in Heaps hxd.Window.js.hx onMouseWheel method.
				appInstance.sevents.onEvent(e);
			}
		}
	}

	@:keep @:noCompletion private function __onTouchBegin(te:TouchEvent):Void
	{
		__mousePoint.x = te.localX;
		__mousePoint.y = te.localY;

		if (__mousePoint.x > 0 && __mousePoint.x < __width && __mousePoint.y > 0 && __mousePoint.y < __height)
		{
			var e = new Event(EPush, __mousePoint.x, __mousePoint.y);
			e.touchId = te.touchPointID;
			appInstance.sevents.onEvent(e);
		}
	}

	@:keep @:noCompletion private function __onTouchMove(te:TouchEvent)
	{
		__mousePoint.x = te.localX;
		__mousePoint.y = te.localY;

		if (__mousePoint.x > 0 && __mousePoint.x < __width && __mousePoint.y > 0 && __mousePoint.y < __height)
		{
			#if (js || flash)
			@:privateAccess __window.openFLMouseX = __mousePoint.x;
			@:privateAccess __window.openFLMouseY = __mousePoint.y;
			#else
			appInstance.sevents.setMousePos(__mousePoint.x, __mousePoint.y);
			#end
			var e = new Event(EMove, __mousePoint.x, __mousePoint.y);
			e.touchId = te.touchPointID;
			appInstance.sevents.onEvent(e);
		}
	}

	@:keep @:noCompletion private function __onTouchEnd(te:TouchEvent):Void
	{
		__mousePoint.x = te.localX;
		__mousePoint.y = te.localY;

		if (__mousePoint.x > 0 && __mousePoint.x < __width && __mousePoint.y > 0 && __mousePoint.y < __height)
		{
			var e = new Event(ERelease, __mousePoint.x, __mousePoint.y);
			e.touchId = te.touchPointID;
			appInstance.sevents.onEvent(e);
		}
	}

	@:keep @:noCompletion private function __onKeyDown(ke:KeyboardEvent)
	{
		var e = new Event(EKeyDown, __mousePoint.x, __mousePoint.y);
		e.keyCode = ke.keyCode;
		hxd.Window.getInstance().event(e);
	}

	@:keep @:noCompletion private function __onKeyUp(ke:KeyboardEvent):Void
	{
		var e = new Event(EKeyUp, __mousePoint.x, __mousePoint.y);
		e.keyCode = ke.keyCode;
		hxd.Window.getInstance().event(e);
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

	public static function toHeapsBitmapData(bmd:BitmapData):hxd.BitmapData
	{
		return hxd.BitmapData.fromNative(#if !flash bmd.image #else bmd #end);
	}

	#if js
	public static function savePNG(bmd:openfl.display.BitmapData, fName:String = "thumbnail.png")
	{
		lime._internal.graphics.ImageCanvasUtil.convertToCanvas(bmd.image);
		@:privateAccess var can = bmd.image.buffer.__srcCanvas;
		untyped
		{
			var link = js.Browser.document.createElement('a');
			link.download = fName;
			link.href = can.toDataURL();
			link.click();
		}
	}
	#else
	public static function savePNG(bmd:openfl.display.BitmapData, fName:String = "thumbnail.png")
	{
		var fullName = lime.system.System.documentsDirectory + fName;
		#if !(android || ios) // Not working on Android
		sys.io.File.saveBytes(fullName, bmd.image.encode(lime.graphics.ImageFileFormat.PNG));
		#end
	}
	#end
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

	public static function syncedRenderCalls():Void {}

	public function updateContainer() {}

	public function renderContainer()
	{
		trace("Doing Nothing!!!");
	}
}
#end
