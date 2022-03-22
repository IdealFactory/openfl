package openfl.display._internal;

import openfl._internal.renderer.svg.SVGTextField;
import openfl.display._internal.CairoTextField;
import openfl.display._internal.CanvasTextField;
import openfl.display.OpenGLRenderer;
import openfl.text.TextField;

#if !openfl_debug
@:fileXml(' tags="haxe,release" ')
@:noDebug
#end
@:access(openfl.display.Graphics)
@:access(openfl.text.TextField)
@SuppressWarnings("checkstyle:FieldDocComment")
class Context3DTextField
{
	public static function render(textField:TextField, renderer:OpenGLRenderer):Void
	{
		if (textField.defaultTextFormat.useSVGFont)
		{
			SVGTextField.render(textField, cast renderer.__softwareRenderer, textField.__worldTransform);
		}
		else
		{
			#if (js && html5)
			CanvasTextField.render(textField, cast renderer.__softwareRenderer, textField.__worldTransform);
			#elseif lime_cairo
			CairoTextField.render(textField, cast renderer.__softwareRenderer, textField.__worldTransform);
			#end
		}
		textField.__graphics.__hardwareDirty = false;
	}

	public static function renderDrawable(textField:TextField, renderer:OpenGLRenderer):Void
	{
		renderer.__updateCacheBitmap(textField, false);

		if (textField.__cacheBitmap != null && !textField.__isCacheBitmapRender)
		{
			Context3DBitmap.render(textField.__cacheBitmap, renderer);
		}
		else
		{
			if (textField.defaultTextFormat.useSVGFont)
			{
				SVGTextField.render(textField, renderer, textField.__worldTransform);
			}
			else
			{
				Context3DTextField.render(textField, renderer);
			}

			if (textField.defaultTextFormat.useSVGFont)
			{
				renderer.__pushMaskRect(new openfl.geom.Rectangle(0, 0, textField.__svgClipWidth, textField.__svgClipHeight), textField.__renderTransform);
			}
			Context3DDisplayObject.render(textField, renderer);
			if (textField.defaultTextFormat.useSVGFont)
			{
				renderer.__popMaskRect();

				textField.__dirty = false;
				textField.__graphics.__softwareDirty = false;
				textField.__graphics.__dirty = false;
			}
		}

		renderer.__renderEvent(textField);
	}

	public static function renderDrawableMask(textField:TextField, renderer:OpenGLRenderer):Void
	{
		Context3DTextField.renderMask(textField, renderer);
		Context3DDisplayObject.renderDrawableMask(textField, renderer);
	}

	public static function renderMask(textField:TextField, renderer:OpenGLRenderer):Void
	{
		if (textField.defaultTextFormat.useSVGFont)
		{
			SVGTextField.render(textField, cast renderer.__softwareRenderer, textField.__worldTransform);
		}
		else
		{
			#if (js && html5)
			CanvasTextField.render(textField, cast renderer.__softwareRenderer, textField.__worldTransform);
			#elseif lime_cairo
			CairoTextField.render(textField, cast renderer.__softwareRenderer, textField.__worldTransform);
			#end
		}
		textField.__graphics.__hardwareDirty = false;
	}
}
