package openfl.text;

#if svg
import haxe.xml.Access;
import format.SVG;
import format.svg.Font;
import format.svg.SVGData;
import format.svg.SVGRenderer;
import openfl.display.Graphics;
import openfl.geom.Rectangle;

class SVGFont
{
	static var fontCache:Map<String, Font> = new Map<String, Font>();

	public static var fallbackFont:Font;

	public static function getSVGFont(name:String):Font
	{
		if (fontCache.exists(name)) return fontCache[name];
		return null;
	}

	public static function registerFont(svg:String, name:String = "", src:String = ""):Font
	{
		var svgFont = SVGFontProcessor.process(svg);
		var id = name == "" ? svgFont.id : name;
		svgFont.src = src;
		if (fontCache.exists(id))
		{
			fontCache.remove(id);
		}
		fontCache[id] = svgFont;
		return svgFont;
	}

	public static function getGlyph(char:String, font:String):Glyph
	{
		if (char == null || char == "" || font == null || !fontCache.exists(font)) return null;
		var svgFont = fontCache[font];

		if (svgFont.glyphs.exists(char)) return svgFont.glyphs[char];
		else if (fallbackFont != null)
		{
			var g:Glyph;
			if (fallbackFont.glyphs.exists(char)) g = fallbackFont.glyphs[char].clone();
			else
				g = fallbackFont.missingGlyph.clone();
			g.horizAdvX *= svgFont.fontFace.unitsPerEm / fallbackFont.fontFace.unitsPerEm;
			return g;
		}
		return null;
	}

	public static function getSupportedFontChars(font:String):Array<String>
	{
		var svgFont = fontCache[font];
		return svgFont.getSupportedFontChars();
	}

	public static function renderSVGGroup(text:String, font:String, x:Float, y:Float, size:Int, spacing:Float = 0, color:UInt = 0, alpha:Float = 1,
			stroke:Null<UInt> = null, strokeAlpha:Null<Float> = null, strokeWidth:Null<Float> = null, splitStrokeFill:Bool = false,
			gradient:Null<String> = null, strokeGradient:Null<String> = null):String
	{
		if (text == null || text == "" || font == null || !fontCache.exists(font)) return "";

		var svgFont = fontCache[font];

		var fScale = 1 / svgFont.fontFace.unitsPerEm * size;
		var fallbackFScale = 1.;
		if (fallbackFont != null) fallbackFScale = svgFont.fontFace.unitsPerEm / fallbackFont.fontFace.unitsPerEm;

		var gradientID = null;
		var ereg_id = ~/id=['|"]([_a-zA-Z0-9]*)['|"]/g;
		if (gradient != null)
		{
			if (ereg_id.match(gradient)) gradientID = ereg_id.matched(1);
		}

		var strokeGradientID = null;
		if (strokeGradient != null)
		{
			if (ereg_id.match(strokeGradient))
			{
				strokeGradientID = ereg_id.matched(1);
			}
		}
		var content = "<defs>\n"
			+ (gradient != null ? gradient + "\n" : "")
			+ (strokeGradient != null ? strokeGradient + "\n" : "")
			+ "</defs>\n";

		content += svgGroup(svgFont, text, x, y, size, spacing, color, alpha, stroke, strokeAlpha, strokeWidth, splitStrokeFill, gradientID, strokeGradientID);

		#if svgfont_debug
		trace("SVGContent:\n" + content);
		#end

		return content;
	}

	public static function renderText(text:String, font:String, g:Graphics, x:Float, y:Float, size:Int, spacing:Float = 0, color:UInt = 0, alpha:Float = 1,
			stroke:Null<UInt> = null, strokeAlpha:Null<Float> = null, strokeWidth:Null<Float> = null, gradient:Null<String>, strokeGradient:Null<String>)
	{
		if (text == null || text == "" || font == null || !fontCache.exists(font) || g == null) return;

		var svgFont = fontCache[font];

		var gradientID = null;
		var ereg_id = ~/id=['|"]([_a-zA-Z0-9]*)['|"]/g;
		if (gradient != null)
		{
			if (ereg_id.match(gradient)) gradientID = ereg_id.matched(1);
		}

		var strokeGradientID = null;
		if (strokeGradient != null)
		{
			if (ereg_id.match(strokeGradient))
			{
				strokeGradientID = ereg_id.matched(1);
			}
		}

		var content = '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" x="0" y="0" viewBox="0 0 1000 1000">'
			+ "\n"
			+ "<defs>\n"
			+ (gradient != null ? gradient + "\n" : "")
			+ (strokeGradient != null ? strokeGradient + "\n" : "")
			+ "</defs>\n";
		content += svgGroup(svgFont, text, x, y, size, spacing, color, alpha, stroke, strokeAlpha, strokeWidth, false, gradientID, strokeGradientID);
		content += '</svg>' + "\n";

		#if svgfont_debug
		trace("SVGContent:\n" + content);
		#end

		var xml = Xml.parse(content);
		var svg = xml.firstElement();

		var data = new SVGData(xml);
		var renderer = new SVGRenderer(data);
		// g.clear();
		renderer.render(g);
	}

	static function svgGroup(svgFont:Font, text:String, x:Float, y:Float, size:Int, spacing:Float = 0, color:UInt, alpha:Float, stroke:Null<UInt>,
			strokeAlpha:Null<Float>, strokeWidth:Null<Float>, splitStrokeFill:Bool = false, gradientID:Null<String>, strokeGradientID:Null<String>):String
	{
		var xOffset = 0.;
		var yOffset = 0.;

		var fScale = 1 / svgFont.fontFace.unitsPerEm * size;
		var fallbackFScale = 1.;
		if (fallbackFont != null) fallbackFScale = svgFont.fontFace.unitsPerEm / fallbackFont.fontFace.unitsPerEm;

		#if svgfont_debug
		trace("SVGFont.renderText: text:" + text + " x=" + x + " y=" + y + " size=" + size + " spacing=" + spacing);
		trace("Font: " + svgFont.id + " hOrig=" + svgFont.horizOriginX + "/" + svgFont.horizOriginY + " adv=" + svgFont.horizAdvX + "/" + svgFont.vertAdvY
			+ " vert=" + svgFont.vertOriginX + "/" + svgFont.vertOriginY);
		trace("Face: unitsPerEm=" + svgFont.fontFace.unitsPerEm + " ascent=" + svgFont.fontFace.ascent + " descent=" + svgFont.fontFace.descent
			+ " capHeight=" + svgFont.fontFace.capHeight + " xHeight=" + svgFont.fontFace.xHeight + " bbox=" + svgFont.fontFace.bbox);
		trace("Scale: fSc=" + fScale + " fallbackFSc=" + fallbackFScale);
		#end

		var strokeSVG = "";
		if (strokeWidth != null && strokeWidth > 0)
		{
			var strokeCol = stroke != null ? stroke : 0;
			strokeSVG = 'stroke="'
				+ (strokeGradientID == null ? ("#" + StringTools.hex(strokeCol & 0xFFFFFF, 6)) : "url(#" + strokeGradientID + ")")
				+ '" '
				+ (strokeAlpha != 1 && strokeGradientID == null ? 'stroke-opacity="' + strokeAlpha + '"' : '')
				+ ' stroke-width="'
				+ (strokeWidth / fScale)
				+ (splitStrokeFill ? '" ' : '" paint-order="stroke fill" ');
		}

		var fill = gradientID == null ? 'fill="#' + StringTools.hex(color & 0xFFFFFF, 6) + '" ' : 'fill="url(#' + gradientID + ')" ';
		if (alpha != 1 && gradientID == null)
		{
			fill += 'opacity="' + alpha + '" ';
		}

		var content = '<g transform="matrix(' + fScale + ' 0 0 -' + fScale + ' ' + x + ' ' + y + ')">' + "\n";
		var textPath = "";
		for (cIdx in 0...text.length)
		{
			var c = text.substr(cIdx, 1);
			var glyph:Glyph = null;
			var scale = 1.;
			if (svgFont.glyphs.exists(c))
			{
				glyph = svgFont.glyphs[c];
			}
			else if (fallbackFont != null)
			{
				if (fallbackFont.glyphs.exists(c)) glyph = fallbackFont.glyphs[c];
				else
					glyph = fallbackFont.missingGlyph;

				scale = fallbackFScale;
			}
			else
				glyph = svgFont.missingGlyph;

			if (glyph != null)
			{
				if (splitStrokeFill)
				{
					var p = glyph.path;
					p = offsetPath(p, xOffset, yOffset);
					textPath += p + " ";
				}
				else
				{
					var p = glyph.path;
					p = offsetPath(p, xOffset, yOffset);
					textPath += p + " ";
				}
				xOffset += (glyph.horizAdvX * scale);
				xOffset += spacing / fScale;
			}
		}
		if (splitStrokeFill)
		{
			content += '        <path ' + strokeSVG + 'd="' + textPath + '" fill-opacity="0" />' + "\n";
			content += '        <path ' + fill + 'd="' + textPath + '" />' + "\n";
		}
		else
		{
			content += '    <path ' + strokeSVG + fill + 'd="' + textPath + '" />' + "\n";
		}
		content += '</g>' + "\n";

		return content;
	}

	static function offsetPath(p:String, xOff:Float, yOff:Float):String
	{
		var ereg_HV = ~/([H|V])([\-0-9\.]+)/g;
		var ereg_MLT = ~/([M|L|T])([\-0-9\.]+)[\s,]([\-0-9\.]+)/g;
		var ereg_SQ = ~/([S|Q])([\-0-9\.]+)[\s,]([\-0-9\.]+)([\-0-9\.]+)[\s,]([\-0-9\.]+)/g;
		var ereg_C = ~/([C])([\-0-9\.]+)[\s,]([\-0-9\.]+)([\-0-9\.]+)[\s,]([\-0-9\.]+)([\-0-9\.]+)[\s,]([\-0-9\.]+)/g;
		var ereg_A = ~/([A])([\-0-9\.]+)[\s,]([\-0-9\.]+)([\-0-9\.]+)[\s,]([\-0-9\.]+)[\s,]([\-0-9\.]+)[\s,]([\-0-9\.]+)[\s,]([\-0-9\.]+)/g;

		var input = p;
		// Match H & V - single parameter
		while (ereg_HV.match(input))
		{
			var m = ereg_HV.matched(0);
			var cmd = ereg_HV.matched(1);
			var x = Std.parseFloat(ereg_HV.matched(2)) + xOff;
			trace("Match-HV: m=" + m + " new=" + cmd + x + " offsets=" + xOff);
			p = StringTools.replace(p, m, cmd + x);
			input = ereg_HV.matchedRight();
		}

		// Match M, L, & T - x & y parameters
		while (ereg_MLT.match(input))
		{
			var m = ereg_MLT.matched(0);
			var cmd = ereg_MLT.matched(1);
			var x = Std.parseFloat(ereg_MLT.matched(2)) + xOff;
			var y = Std.parseFloat(ereg_MLT.matched(3)) + yOff;
			// trace("Match-MLT: m=" + m + " new=" + cmd + x + " " + y + " offsets=" + xOff + "/" + yOff);
			p = StringTools.replace(p, m, cmd + x + " " + y);
			input = ereg_MLT.matchedRight();
		}

		// TODO : ereg_SQ, ereg_C & ereg_A
		return p;
	}
}

class SVGFontProcessor
{
	var svg:Xml;

	static public function process(content:String):Font
	{
		var xml = Xml.parse(content);
		var svg = xml.firstElement();

		var svgData = new SVGData(xml);
		return svgData.svgFont;
	}

	static private function getFloat(inXML:Xml, inName:String, inDef:Float = 0.0):Float
	{
		if (inXML.exists(inName)) return Std.parseFloat(inXML.get(inName));

		return inDef;
	}

	static private function getInt(inXML:Xml, inName:String, inDef:Int = 0):Int
	{
		if (inXML.exists(inName)) return Std.parseInt(inXML.get(inName));

		return inDef;
	}
}
#else
class SVGFont {}
#end
