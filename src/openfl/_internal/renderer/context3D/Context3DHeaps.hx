package openfl._internal.renderer.context3D;

import openfl.display.HeapsContainer;
import openfl.display.OpenGLRenderer;
#if gl_stats
import openfl._internal.renderer.context3D.stats.Context3DStats;
import openfl._internal.renderer.context3D.stats.DrawCallContext;
#end
import hxd.System;
import hxd.Window;

#if !openfl_debug
@:fileXml(' tags="haxe,release" ')
@:noDebug
#end
@:access(openfl.display3D.Context3D)
@:access(openfl.display.HeapsContainer)
@:access(openfl.display.Stage)
@:access(openfl.display.Shader)
@SuppressWarnings("checkstyle:FieldDocComment")
class Context3DHeaps
{
	public static function render(heaps:HeapsContainer, renderer:OpenGLRenderer):Void
	{
		if (!heaps.__renderable || heaps.__worldAlpha <= 0) return;

		if (heaps.__appClass != null && heaps.__bitmapData != null)
		{
			var context = renderer.__context3D;

			renderer.__setBlendMode(heaps.__worldBlendMode);
			renderer.__pushMaskObject(heaps);

			var shader = renderer.__initDisplayShader(cast heaps.__worldShader);
			renderer.setShader(shader);
			renderer.applyBitmapData(heaps.__bitmapData, renderer.__allowSmoothing && (heaps.smoothing || renderer.__upscaled));
			renderer.applyMatrix(renderer.__getMatrix(heaps.__renderTransform, heaps.pixelSnapping));
			renderer.applyAlpha(heaps.__worldAlpha);
			renderer.applyColorTransform(heaps.__worldColorTransform);
			renderer.updateShader();

			var vertexBuffer = heaps.__bitmapData.getVertexBuffer(context);
			if (shader.__position != null) context.setVertexBufferAt(shader.__position.index, vertexBuffer, 0, FLOAT_3);
			if (shader.__textureCoord != null) context.setVertexBufferAt(shader.__textureCoord.index, vertexBuffer, 3, FLOAT_2);
			var indexBuffer = heaps.__bitmapData.getIndexBuffer(context);
			context.drawTriangles(indexBuffer);

			#if gl_stats
			Context3DStats.incrementDrawCall(DrawCallContext.STAGE);
			#end

			renderer.__clearShader();

			// renderer.filterManager.popObject (heaps);
			renderer.__popMaskObject(heaps);
		}
	}
	// public static function renderMask(heaps:Bitmap, renderer:OpenGLRenderer):Void
	// {
	// 	if (heaps.__bitmapData != null && heaps.__bitmapData.__isValid)
	// 	{
	// 		var context = renderer.__context3D;
	// 		var shader = renderer.__maskShader;
	// 		renderer.setShader(shader);
	// 		renderer.applyBitmapData(Context3DMaskShader.opaqueBitmapData, true);
	// 		renderer.applyMatrix(renderer.__getMatrix(heaps.__renderTransform, heaps.pixelSnapping));
	// 		renderer.updateShader();
	// 		var vertexBuffer = heaps.__bitmapData.getVertexBuffer(context);
	// 		if (shader.__position != null) context.setVertexBufferAt(shader.__position.index, vertexBuffer, 0, FLOAT_3);
	// 		if (shader.__textureCoord != null) context.setVertexBufferAt(shader.__textureCoord.index, vertexBuffer, 3, FLOAT_2);
	// 		var indexBuffer = heaps.__bitmapData.getIndexBuffer(context);
	// 		context.drawTriangles(indexBuffer);
	// 		#if gl_stats
	// 		Context3DStats.incrementDrawCall(DrawCallContext.STAGE);
	// 		#end
	// 		renderer.__clearShader();
	// 	}
	// }
}
