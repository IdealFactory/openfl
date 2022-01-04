package openfl.text;

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

	public static function renderSVGGroup(text:String, font:String, x:Float, y:Float, size:Int, color:UInt = 0, stroke:Null<UInt> = null,
			strokeWidth:Null<Float> = null):String
	{
		if (text == null || text == "" || font == null || !fontCache.exists(font)) return "";

		var svgFont = fontCache[font];

		var fScale = 1 / svgFont.fontFace.unitsPerEm * size;
		var fallbackFScale = 1.;
		if (fallbackFont != null) fallbackFScale = svgFont.fontFace.unitsPerEm / fallbackFont.fontFace.unitsPerEm;

		var content = svgGroup(svgFont, text, x, y, size, color, stroke, strokeWidth);

		#if svgfont_debug
		trace("SVGContent:\n" + content);
		#end

		return content;
	}

	public static function renderText(text:String, font:String, g:Graphics, x:Float, y:Float, size:Int, color:UInt = 0, stroke:Null<UInt> = null,
			strokeWidth:Null<Float> = null)
	{
		if (text == null || text == "" || font == null || !fontCache.exists(font) || g == null) return;

		var svgFont = fontCache[font];

		var content = '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" x="0" y="0" viewBox="0 0 1000 1000">'
			+ "\n";
		content += svgGroup(svgFont, text, x, y, size, color, stroke, strokeWidth);
		content += '</svg>' + "\n";

		#if svgfont_debug
		trace("SVGContent:\n" + content);
		#end

		var xml = Xml.parse(content);
		var svg = xml.firstElement();

		var data = new SVGData(xml);
		var renderer = new SVGRenderer(data);
		renderer.render(g);
	}

	static function svgGroup(svgFont:Font, text:String, x:Float, y:Float, size:Int, color:UInt, stroke:Null<UInt>, strokeWidth:Null<Float>):String
	{
		#if svgfont_debug
		trace("SVGFont.renderText: text:" + text);
		trace("Font: " + svgFont.id + " hOrig=" + svgFont.horizOriginX + "/" + svgFont.horizOriginY + " adv=" + svgFont.horizAdvX + "/" + svgFont.vertAdvY
			+ " vert=" + svgFont.vertOriginX + "/" + svgFont.vertOriginY);
		trace("Face: unitsPerEm=" + svgFont.fontFace.unitsPerEm + " ascent=" + svgFont.fontFace.ascent + " descent=" + svgFont.fontFace.descent
			+ " capHeight=" + svgFont.fontFace.capHeight + " xHeight=" + svgFont.fontFace.xHeight + " bbox=" + svgFont.fontFace.bbox);
		#end

		var xOffset = 0.;
		var yOffset = 0.;

		var fScale = 1 / svgFont.fontFace.unitsPerEm * size;
		var fallbackFScale = 1.;
		if (fallbackFont != null) fallbackFScale = svgFont.fontFace.unitsPerEm / fallbackFont.fontFace.unitsPerEm;

		var strokeSVG = "";
		if (strokeWidth != null && strokeWidth > 0)
		{
			var strokeCol = stroke != null ? stroke : 0;
			strokeSVG = 'stroke="'
				+ "#"
				+ StringTools.hex(strokeCol & 0xFFFFFF, 6)
				+ '" stroke-width="'
				+ (strokeWidth / fScale)
				+ '" stroke-style="outside"';
		}

		var content = '<g transform="matrix(' + fScale + ' 0 0 -' + fScale + ' ' + x + ' ' + y + ')">' + "\n";
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
				content += '    <g transform="matrix(' + scale + ' 0 0 ' + scale + ' ' + xOffset + ' ' + yOffset + ')" >' + "\n";
				content += '        <path '
					+ strokeSVG
					+ 'fill="'
					+ "#"
					+ StringTools.hex(color & 0xFFFFFF, 6)
					+ '" d="'
					+ glyph.path
					+ '" />'
					+ "\n";
				content += '    </g>' + "\n";
				xOffset += (glyph.horizAdvX * scale);
			}
		}
		content += '</g>' + "\n";

		return content;
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
