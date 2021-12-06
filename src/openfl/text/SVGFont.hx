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

	public static function getSVGFont(name:String):Font
	{
		if (fontCache.exists(name)) return fontCache[name];
		return null;
	}

	public static function registerFont(svg:String)
	{
		var svgFont = SVGFontProcessor.process(svg);
		if (fontCache.exists(svgFont.id))
		{
			fontCache.remove(svgFont.id);
		}
		fontCache[svgFont.id] = svgFont;
	}

	public static function getGlyph(char:String, font:String):Glyph
	{
		if (char == null || char == "" || font == null || !fontCache.exists(font)) return null;
		var svgFont = fontCache[font];

		if (svgFont.glyphs.exists(char)) return svgFont.glyphs[char];
		return null;
	}

	public static function renderText(text:String, font:String, g:Graphics, x:Float, y:Float, size:Int, color:UInt = 0)
	{
		if (text == null || text == "" || font == null || !fontCache.exists(font) || g == null)
		{
			return;
		}

		var svgFont = fontCache[font];
		var xOffset = 0.;
		var yOffset = 0.;

		#if svgfont_debug
		trace("SVGFont.renderText: text:" + text);
		trace("Font: " + svgFont.id + " hOrig=" + svgFont.horizOriginX + "/" + svgFont.horizOriginY + " adv=" + svgFont.horizAdvX + "/" + svgFont.vertAdvY
			+ " vert=" + svgFont.vertOriginX + "/" + svgFont.vertOriginY);
		trace("Face: unitsPerEm=" + svgFont.fontFace.unitsPerEm + " ascent=" + svgFont.fontFace.ascent + " descent=" + svgFont.fontFace.descent
			+ " capHeight=" + svgFont.fontFace.capHeight + " xHeight=" + svgFont.fontFace.xHeight + " bbox=" + svgFont.fontFace.bbox);
		#end

		var content = '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" x="0" y="0" viewBox="0 0 1000 1000">'
			+ "\n";

		var fScale = 1 / svgFont.fontFace.unitsPerEm * size;
		content += '<g transform="matrix(' + fScale + ' 0 0 -' + fScale + ' ' + x + ' ' + y + ')">' + "\n";
		for (cIdx in 0...text.length)
		{
			var c = text.substr(cIdx, 1);
			var cdbg = " - not rendered";
			if (svgFont.glyphs.exists(c))
			{
				var glyph = svgFont.glyphs[c];
				content += '    <g transform="matrix(1 0 0 1 ' + xOffset + ' ' + yOffset + ')" >' + "\n";
				content += '        <path fill="' + "#" + StringTools.hex(color & 0xFFFFFF, 6) + '" d="' + glyph.path + '" />' + "\n";
				content += '    </g>' + "\n";
				xOffset += glyph.horizAdvX;
				cdbg = " adv=" + glyph.horizAdvX + "/" + glyph.vertAdvY + " orig:" + glyph.vertOriginX + "/" + glyph.vertOriginY;
			}
		}
		content += '</g>' + "\n";
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
