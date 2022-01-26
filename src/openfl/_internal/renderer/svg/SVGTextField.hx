package openfl._internal.renderer.svg;

import openfl._internal.text.TextEngine;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Graphics;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;
import openfl.geom.Point;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.SVGFont;
#if js
import js.Browser;
#end

@:access(openfl._internal.text.TextEngine)
@:access(openfl.display.Graphics)
@:access(openfl.geom.Matrix)
@:access(openfl.text.TextField)
@:access(openfl.text.TextFormat)
@SuppressWarnings("checkstyle:FieldDocComment")
class SVGTextField
{
	public static inline function render(textField:TextField, renderer:Dynamic, transform:Matrix):Void
	{
		var textEngine = textField.__textEngine;
		var bounds = (textEngine.background || textEngine.border) ? textEngine.bounds : textEngine.textBounds;
		var graphics = textField.__graphics;

		if (textField.__dirty)
		{
			textField.__updateLayout();

			var b = textField.getBounds(textField);
			textField.__svgClipWidth = Std.int(b.width);
			textField.__svgClipHeight = Std.int(b.height);

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
			var width = graphics.__width;
			var height = graphics.__height;

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

					graphics.drawRect(0, 0, bounds.width, bounds.height);

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

						SVGFont.renderText(groupText, group.format.font, graphics, tx, ty, group.format.size, group.format.letterSpacing, group.format.color,
							group.format.stroke, group.format.strokeWidth);

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
									graphics.moveTo(group.offsetX + advance, scrollY + 2 - bounds.y);
									graphics.lineTo(group.offsetX + advance, scrollY + TextEngine.getFormatHeight(textField.defaultTextFormat) - 1 - bounds.y);

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
									graphics.drawRect(start.x + scrollX, start.y + scrollY, end.x - start.x, group.height);
									graphics.beginFill(0xffffff);

									// TODO: fill only once
									SVGFont.renderText(text.substring(selectionStart, selectionEnd), group.format.font, textField.__graphics, start.x,
										group.offsetY + group.ascent, group.format.size, group.format.letterSpacing, 0xffffff, group.format.stroke,
										group.format.strokeWidth);
								}
							}
						}

						if (group.format.underline)
						{
							graphics.lineStyle(1, color);
							var x = group.offsetX + scrollX - bounds.x;
							var y = Math.floor(group.offsetY + scrollY + group.ascent - bounds.y) + 0.5;
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
						graphics.moveTo(scrollX + 2, scrollY + 2 - bounds.y);
						graphics.lineTo(scrollX + 2, scrollY + TextEngine.getFormatHeight(textField.defaultTextFormat) - 1 - bounds.y);
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

	public static inline function renderSVGGroup(textField:TextField, transform:Matrix):String
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
				group.format.stroke, group.format.strokeWidth);
		}

		return svg;
	}
}
