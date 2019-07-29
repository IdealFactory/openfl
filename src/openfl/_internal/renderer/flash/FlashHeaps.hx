package openfl._internal.renderer.flash;

import openfl.display.HeapsContainer;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.display3D.Context3DBlendFactor;
import openfl.display3D.Context3DProgramType;
import openfl.geom.ColorTransform;
import openfl.geom.Matrix;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import h3d.Engine;
import hxd.System;
import hxd.Window;

@:access(openfl.display3D.Context3D)
@:access(openfl.display.HeapsContainer)
@:access(openfl.display.Stage)
@:access(openfl.display.Shader)
@SuppressWarnings("checkstyle:FieldDocComment")
class FlashHeaps
{
	public static function render(heaps:HeapsContainer):Void
	{
		if (heaps.__appClass != null && heaps.__bitmapData != null)
		{
			var driver:h3d.impl.Stage3dDriver = cast Engine.getCurrent().driver;
			@:privateAccess var context = driver.ctx;

			var a = 0;
			a += 100;
			context.setProgram(heaps.__heapsRenderbufferProgram);
			context.setVertexBufferAt(0, heaps.__vertexBuffer, 0, FLOAT_3);
			context.setVertexBufferAt(1, heaps.__vertexBuffer, 3, FLOAT_2);

			var pt = heaps.localToGlobal(new Point());

			heaps.__transform.identity();
			var raw = heaps.__transform.rawData;
			raw[0] = heaps.transform.concatenatedMatrix.a;
			raw[1] = heaps.transform.concatenatedMatrix.b;
			raw[4] = heaps.transform.concatenatedMatrix.c;
			raw[5] = heaps.transform.concatenatedMatrix.d;
			raw[12] = heaps.transform.concatenatedMatrix.tx;
			raw[13] = heaps.transform.concatenatedMatrix.ty;
			heaps.__transform.rawData = raw;
			heaps.__transform.append(heaps.__projection);

			context.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 0, heaps.__transform, true);
			context.setBlendFactors(Context3DBlendFactor.ONE, Context3DBlendFactor.ZERO);
			context.setTextureAt(0, heaps.__heapsRenderbufferTexture);
			context.drawTriangles(heaps.__indexBuffer);
		}
	}
}
