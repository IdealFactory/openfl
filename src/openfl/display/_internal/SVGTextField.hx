package openfl.display._internal;

import openfl.geom.Matrix;
import openfl.text.TextField;
#if svg
import openfl.text._internal.TextEngine;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Graphics;
import openfl.geom.Rectangle;
import openfl.geom.Point;
import openfl.text.TextFieldAutoSize;
import openfl.text.SVGFont;
#if js
import js.Browser;
#end

@:access(openfl.text._internal.TextEngine)
@:access(openfl.display.Graphics)
@:access(openfl.geom.Matrix)
@:access(openfl.text.TextField)
@:access(openfl.text.TextFormat)
@SuppressWarnings("checkstyle:FieldDocComment")
class SVGTextField
{
	static var lastPixelRatio:Int = 0;

	public static function render(textField:TextField, renderer:Dynamic, transform:Matrix):Void
	{
		var textEngine = textField.__textEngine;
		var bounds = (textEngine.background || textEngine.border) ? textEngine.bounds : textEngine.textBounds;
		var graphics = textField.__graphics;

		#if (openfl_disable_hdpi || openfl_disable_hdpi_textfield)
		var pixelRatio = 1;
		#else
		var pixelRatio = renderer.__pixelRatio;
		#end

		if (lastPixelRatio != pixelRatio) textField.__dirty = true;
		lastPixelRatio = pixelRatio;

		if (textField.__dirty)
		{
			textField.__updateLayout();

			var b = textField.getBounds(textField);
			textField.__svgClipWidth = Std.int(b.width * pixelRatio);
			textField.__svgClipHeight = Std.int(b.height * pixelRatio);

			graphics.clear();

			if (graphics.__bounds == null)
			{
				graphics.__bounds = new Rectangle();
			}

			graphics.__bounds.copyFrom(bounds);
		}

		graphics.__update(renderer.__worldTransform);

		if (textField.__dirty || graphics.__softwareDirty)
		{
			var width = graphics.__width * pixelRatio;
			var height = graphics.__height * pixelRatio;

			var initialScrollX = -999999.0;
			var initialScrollY = -999999.0;

			if (((textEngine.text == null || textEngine.text == "")
				&& !textEngine.background
				&& !textEngine.border
				&& !textEngine.__hasFocus
				&& (textEngine.type != INPUT || !textEngine.selectable))
				|| ((textEngine.width <= 0 || textEngine.height <= 0) && textEngine.autoSize != TextFieldAutoSize.NONE))
			{
				#if (js && html5)
				if (textField.__graphics.__canvas != null) textField.__graphics.__canvas.width = textField.__graphics.__canvas.height = 1;
				textField.__graphics.__canvas = null;
				textField.__graphics.__context = null;
				#else
				textField.__graphics.__cairo = null;
				#end
				textField.__dirty = false;
			}
			else
			{
				var matrix = Matrix.__pool.get();
				matrix.scale(pixelRatio, pixelRatio);
				matrix.concat(graphics.__renderTransform);
				graphics.__renderTransform.copyFrom(matrix);
				graphics.__bitmapScale = pixelRatio;

				if (textEngine.border || textEngine.background)
				{
					if (textEngine.border)
					{
						graphics.lineStyle(1, textEngine.borderColor);
					}

					if (textEngine.background)
					{
						graphics.beginFill(1, textEngine.backgroundColor);
					}

					graphics.drawRect(0, 0, bounds.width * pixelRatio, bounds.height * pixelRatio);

					if (textEngine.background)
					{
						graphics.endFill();
					}
					if (textEngine.border)
					{
						graphics.lineStyle();
					}
				}

				if ((textEngine.text != null && textEngine.text != "") || textEngine.__hasFocus)
				{
					var text = textEngine.text;

					var scrollX = -textField.scrollH;
					var scrollY = 0.0;

					for (i in 0...textField.scrollV - 1)
					{
						scrollY -= textEngine.lineHeights[i];
					}

					initialScrollX = scrollX;
					initialScrollY = scrollY;

					for (group in textEngine.layoutGroups)
					{
						var color = "#" + StringTools.hex(group.format.color & 0xFFFFFF, 6);

						var font = TextEngine.getFont(group.format);

						var groupText = text.substring(group.startIndex, group.endIndex);
						var tx = group.offsetX;
						var ty = group.offsetY + group.ascent;

						SVGFont.renderText(groupText, group.format.font, graphics, tx * pixelRatio, ty * pixelRatio, group.format.size * pixelRatio,
							group.format.letterSpacing, group.format.color, textField.alpha, group.format.stroke, group.format.strokeAlpha,
							group.format.strokeWidth, group.format.gradient, group.format.strokeGradient);

						if (textField.__caretIndex > -1 && textEngine.selectable)
						{
							if (textField.__selectionIndex == textField.__caretIndex)
							{
								if (textField.__showCursor
									&& group.startIndex <= textField.__caretIndex
									&& group.endIndex >= textField.__caretIndex)
								{
									var advance = 0.0;

									for (i in 0...(textField.__caretIndex - group.startIndex))
									{
										if (group.positions.length <= i) break;
										advance += group.getAdvance(i);
									}

									var scrollY = 0.0;

									for (i in textField.scrollV...(group.lineIndex + 1))
									{
										scrollY += textEngine.lineHeights[i - 1];
									}

									graphics.lineStyle(1, group.format.color & 0xFFFFFF);
									graphics.moveTo((group.offsetX + advance) * pixelRatio, (scrollY + 2 - bounds.y) * pixelRatio);
									graphics.lineTo((group.offsetX + advance) * pixelRatio,
										(scrollY + TextEngine.getFormatHeight(textField.defaultTextFormat) - 1 - bounds.y) * pixelRatio);

									graphics.lineStyle();
								}
							}
							else if ((group.startIndex <= textField.__caretIndex && group.endIndex >= textField.__caretIndex)
								|| (group.startIndex <= textField.__selectionIndex && group.endIndex >= textField.__selectionIndex)
								|| (group.startIndex > textField.__caretIndex && group.endIndex < textField.__selectionIndex)
								|| (group.startIndex > textField.__selectionIndex && group.endIndex < textField.__caretIndex))
							{
								var selectionStart = Std.int(Math.min(textField.__selectionIndex, textField.__caretIndex));
								var selectionEnd = Std.int(Math.max(textField.__selectionIndex, textField.__caretIndex));

								if (group.startIndex > selectionStart)
								{
									selectionStart = group.startIndex;
								}

								if (group.endIndex < selectionEnd)
								{
									selectionEnd = group.endIndex;
								}

								var start, end;

								start = textField.getCharBoundaries(selectionStart);

								if (selectionEnd >= group.endIndex)
								{
									end = textField.getCharBoundaries(group.endIndex - 1);
									if (end != null) end.x += end.width + 2;
								}
								else
								{
									end = textField.getCharBoundaries(selectionEnd);
								}

								if (start != null && end != null)
								{
									graphics.beginFill(0);
									graphics.drawRect((start.x + scrollX) * pixelRatio, (start.y + scrollY) * pixelRatio, (end.x - start.x) * pixelRatio,
										(group.height) * pixelRatio);
									graphics.beginFill(0xffffff);

									// TODO: fill only once
									SVGFont.renderText(text.substring(selectionStart, selectionEnd), group.format.font, textField.__graphics,
										start.x * pixelRatio, (group.offsetY + group.ascent) * pixelRatio, group.format.size * pixelRatio,
										group.format.letterSpacing, 0xffffff, textField.alpha, group.format.stroke, group.format.strokeAlpha,
										group.format.strokeWidth, group.format.gradient, group.format.strokeGradient);
								}
							}
						}

						if (group.format.underline)
						{
							graphics.lineStyle(1, color);
							var x = (group.offsetX + scrollX - bounds.x) * pixelRatio;
							var y = (Math.floor(group.offsetY + scrollY + group.ascent - bounds.y) + 0.5) * pixelRatio;
							graphics.moveTo(x, y);
							graphics.lineTo(x + group.width, y);
						}
					}
				}
				else
				{
					if (textField.__caretIndex > -1 && textEngine.selectable && textField.__showCursor)
					{
						var scrollX = -textField.scrollH;
						var scrollY = 0.0;

						for (i in 0...textField.scrollV - 1)
						{
							scrollY += textEngine.lineHeights[i];
						}

						initialScrollX = scrollX;
						initialScrollY = scrollY;

						graphics.lineStyle(1, textField.defaultTextFormat.color & 0xFFFFFF);
						graphics.moveTo((scrollX + 2) * pixelRatio, (scrollY + 2 - bounds.y) * pixelRatio);
						graphics.lineTo((scrollX + 2) * pixelRatio,
							(scrollY + TextEngine.getFormatHeight(textField.defaultTextFormat) - 1 - bounds.y) * pixelRatio);
						graphics.lineStyle();
					}
				}
			}

			if (initialScrollX != -999999.0 && initialScrollY != -999999.0)
			{
				var pt = new Point(initialScrollX, initialScrollY);
				var dtXY = graphics.__renderTransform.deltaTransformPoint(pt);
				var m = Matrix.__pool.get();
				m.translate(dtXY.x, dtXY.y);
				graphics.__svgOffsetX = dtXY.x;
				graphics.__svgOffsetY = dtXY.y;
			}
		}
	}

	public static inline function renderSVGGroup(textField:TextField, transform:Matrix, splitStrokeFill:Bool = false):String
	{
		var textEngine = textField.__textEngine;
		var bounds = (textEngine.background || textEngine.border) ? textEngine.bounds : textEngine.textBounds;
		var graphics = textField.__graphics;

		if (textField.__dirty)
		{
			textField.__updateLayout();
		}

		var text = textEngine.text;

		var scrollX = -textField.scrollH;
		var scrollY = 0.0;

		for (i in 0...textField.scrollV - 1)
		{
			scrollY -= textEngine.lineHeights[i];
		}

		var svg = "";
		for (group in textEngine.layoutGroups)
		{
			var color = "#" + StringTools.hex(group.format.color & 0xFFFFFF, 6);

			var font = TextEngine.getFont(group.format);

			var groupText = text.substring(group.startIndex, group.endIndex);
			var tx = group.offsetX;
			var ty = group.offsetY + group.ascent;

			svg += SVGFont.renderSVGGroup(groupText, group.format.font, tx, ty, group.format.size, group.format.letterSpacing, group.format.color,
				textField.alpha, group.format.stroke, group.format.strokeAlpha, group.format.strokeWidth, splitStrokeFill, group.format.gradient,
				group.format.strokeGradient);
		}

		return svg;
	}
}
#else
class SVGTextField
{
	public static inline function render(textField:TextField, renderer:Dynamic, transform:Matrix):Void {}
}
#end
